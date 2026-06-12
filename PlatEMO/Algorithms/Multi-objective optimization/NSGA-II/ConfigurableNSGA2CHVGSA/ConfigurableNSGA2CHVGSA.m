classdef ConfigurableNSGA2CHVGSA < ALGORITHM
% <multi> <real/integer/label/binary/permutation> <constrained/none>
% Configurable NSGA-II with C-HVGSA local search
%
%   A unified algorithm class that supports all NSGA-II + C-HVGSA variants
%   through a config struct rather than separate class files.
%
%   Usage:
%     % Default (= Ablation-VI base NSGA2CHVGSA)
%     platemo('algorithm', {@ConfigurableNSGA2CHVGSA, struct()}, ...)
%
%     % Without normalization (= NSGA2CHVGSAWN)
%     platemo('algorithm', {@ConfigurableNSGA2CHVGSA, struct('use_normalization', 'off')}, ...)
%
%     % Objective-only normalization (= NSGA2CHVGSAON)
%     platemo('algorithm', {@ConfigurableNSGA2CHVGSA, struct('use_normalization', 'obj')}, ...)
%
%     % Fixed reference constant (= NSGA2CHVGSAR1p1)
%     platemo('algorithm', {@ConfigurableNSGA2CHVGSA, struct('refC', 1.1)}, ...)
%
%     % Constant step size (= NSGA2CHVGSAO)
%     platemo('algorithm', {@ConfigurableNSGA2CHVGSA, ...
%         struct('use_normalization', 'off', 'eta_mode', 'constant_one')}, ...)

%------------------------------- Reference --------------------------------
% K. Deb, A. Pratap, S. Agarwal, and T. Meyarivan, A fast and elitist
% multiobjective genetic algorithm: NSGA-II, IEEE Transactions on
% Evolutionary Computation, 2002, 6(2): 182-197.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2024 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    methods
        function main(Algorithm,Problem)
            %% Parse config and HID
            [configIn, HID] = Algorithm.ParameterSet(struct(), "");
            config = parseCHVGSAConfig(configIn);

            %% Set save name
            variantName = config2name_CHVGSA(config);
            Algorithm.SetSaveName(variantName);

            %% Eta setup
            [base_eta, goal_eta] = getEtaBounds(config, Problem.D);

            %% Misc parameters from config
            Qsize     = config.Qsize; % Archive size---user-defined (0 disables archive)
            useArchive = Qsize > 0;
            norm_eps  = config.norm_eps; % Not user-defined
            sr_mode   = config.sr_mode; % Clunky user-defined parameter 1
            k_min     = config.k_min; % Clunky user-defined parameter 2 :(
            % k_min = min(Problem.D, k_min);

            %% Generate population (with optional heuristic initialization)
            Population = initPopulation(Problem, HID);
            [~,FrontNo,CrowdDis] = EnvironmentalSelection_NSGAII(Population,Problem.N);

            %% Archive setup
            iter_counter = 1;
            if useArchive
                Archive = PopulationQueue(Qsize);
            end

            eta = base_eta;

            %% Optimization
            while Algorithm.NotTerminated(Population)
                %% Store into archive
                if useArchive
                    Archive.push(Population, iter_counter);
                end

                %% EMOA step
                MatingPool = TournamentSelection(2,Problem.N,FrontNo,-CrowdDis);
                %% OperatorGAdiff is different from OperatorGA in that
                %% it perturbs the offsprings' decision variables
                %% by a tiny perturbation vector (to make sure HVGSA 
                %% won't encounter rank-deficiency as easily)
                % Offspring  = OperatorGAdiff(Problem,Population(MatingPool));
                Offspring = OperatorGA(Problem, Population(MatingPool));
                Mixture = [Population,Offspring];

                % [~,FrontNo,CrowdDis,Next] = EnvironmentalSelection_NSGAII(Mixture,Problem.N);
                % Population = Mixture(Next);

                %% GSA step: determine U
                if strcmp(config.U_mode, 'fixed')
                    U = config.U_value;
                else
                    U = randi(config.U_range, 1);
                end

                %% Get X0 and Archive from source
                if useArchive
                    X0 = Mixture;
                    History = [];
                    for i = 1 : Archive.getSize()
                        History = [History, X0, Archive.get(i).pop];
                    end
                    [~, uniqueX0Ind] = unique(X0.decs, 'rows');
                    [~, uniqueHisInd] = unique(History.decs, 'rows');
                    X0 = X0(uniqueX0Ind);
                    History = History(uniqueHisInd);
                else
                    X0 = Mixture;
                    [~, uniqueX0Ind] = unique(X0.decs, 'rows');
                    X0 = X0(uniqueX0Ind);
                    History = X0;
                end

                %% Determine the non-dominated set
                [TempFrontNo,~] = NDSort(X0.objs,X0.cons,1);
                ND_set_idx = TempFrontNo==1;
                ND_set = X0(ND_set_idx);
                
                if config.use_expanded_front
                    [~, expanded_NDS] = Nondominance(ND_set, X0);
                    ND_set = expanded_NDS;
                end

                %% Branch: normalization vs no normalization
                if ~strcmp(config.use_normalization, 'off')
                    %% Normalize
                    NormStruct_init = struct();
                    if strcmp(config.use_normalization, 'obj')
                        NormStruct_init.normalize_cons = false;
                    end
                    % [~, ~, NormStruct] = NormReference(Mixture.objs, Mixture.cons, NormStruct_init);
                    [~, ~, NormStruct] = NormReference(ND_set.objs, ND_set.cons, NormStruct_init);

                    [Norm_ND_set_objs, Norm_ND_set_cons, ~] = ...
                        NormReference(ND_set.objs, ND_set.cons, NormStruct);
                    Norm_ND_set = SOLUTION(ND_set.decs, Norm_ND_set_objs, Norm_ND_set_cons);

                    [Norm_Archive_objs, Norm_Archive_cons, ~] = ...
                        NormReference(History.objs, History.cons, NormStruct, norm_eps);
                    Norm_History = SOLUTION(History.decs, Norm_Archive_objs, Norm_Archive_cons);

                    [NeighborsArr, Norm_X0, X0_indices] = SelectNeighbors(Norm_ND_set, Norm_History, sr_mode, k_min, U);
                    X0 = ND_set(X0_indices);
                    u = numel(X0);

                    %% Skip if empty
                    if isempty(NeighborsArr)
                        iter_counter = iter_counter + 1;
                        continue;
                    end

                    %% Reference point (normalized space)
                    refConstant = getRefConstant(config.refC, Problem.M, numel(ND_set));
                    ref = ones(1, Problem.M) * refConstant;

                    %% Gradient
                    flat_X0  = Flatten(Norm_X0.decs);
                    flat_FX0 = Flatten(Norm_X0.objs);
                    flat_CX0 = Flatten(Norm_X0.cons);
                    cell_flat_decs = cellfun(@(c) Flatten(c.decs), NeighborsArr, 'UniformOutput', false);
                    flat_Xi = vertcat(cell_flat_decs{:});
                    cell_flat_objs = cellfun(@(c) Flatten(c.objs), NeighborsArr, 'UniformOutput', false);
                    flat_FXi = vertcat(cell_flat_objs{:});
                    cell_flat_cons = cellfun(@(c) Flatten(c.cons), NeighborsArr, 'UniformOutput', false);
                    flat_CXi = vertcat(cell_flat_cons{:});

                    HV_X0 = FeasibleCHV(ref, flat_FX0, flat_CX0);
                    HV_Xi = FeasibleCHV(ref, flat_FXi, flat_CXi);

                    [v, V, lambda, d] = callGradient(config, flat_X0, HV_X0, flat_CX0, flat_Xi, HV_Xi, flat_CXi, u);
                    GSA_HVGrad = v';

                    %% Step
                    if config.use_interpolation
                        [~, ~, Xs, ~] = ConstrainedAdaptiveStepSize( ...
                                            eta, X0, ref, ...
                                            GSA_HVGrad, d, V, lambda, ...
                                            Problem, NormStruct);
                    else
                        %% Flat step (no interpolation, with normalization)
                        % varepsilon = 1e-8;
                        % random_dir = rand(size(GSA_HVGrad));
                        N = size(X0, 2);
                        x0_flat = Flatten(X0.decs);
                        x1_flat = x0_flat + GSA_HVGrad .* eta .* repmat((Problem.upper-Problem.lower), 1, N);
                        x1_decs = Unflatten(x1_flat, N);
                        x1_decs = min(Problem.upper, max(Problem.lower, x1_decs));
                        Xs = Problem.Evaluation(x1_decs);
                    end

                else
                    %% No normalization path
                    [NeighborsArr, X0, X0_indices] = SelectNeighbors(ND_set, History, sr_mode, k_min, U);
                    X0 = ND_set(X0_indices);
                    u = numel(X0);

                    %% Skip if empty
                    if isempty(NeighborsArr)
                        iter_counter = iter_counter + 1;
                        continue;
                    end

                    %% Reference point (raw space)
                    refConstant = getRefConstant(config.refC, Problem.M, numel(ND_set));
                    % ref = BetterRefGetter(Mixture.objs, refConstant);
                    ref = BetterRefGetter(ND_set.objs, refConstant);

                    %% Gradient
                    flat_X0  = Flatten(X0.decs);
                    flat_FX0 = Flatten(X0.objs);
                    flat_CX0 = Flatten(X0.cons);
                    cell_flat_decs = cellfun(@(c) Flatten(c.decs), NeighborsArr, 'UniformOutput', false);
                    flat_Xi = vertcat(cell_flat_decs{:});
                    cell_flat_objs = cellfun(@(c) Flatten(c.objs), NeighborsArr, 'UniformOutput', false);
                    flat_FXi = vertcat(cell_flat_objs{:});
                    cell_flat_cons = cellfun(@(c) Flatten(c.cons), NeighborsArr, 'UniformOutput', false);
                    flat_CXi = vertcat(cell_flat_cons{:});

                    HV_X0 = FeasibleCHV(ref, flat_FX0, flat_CX0);
                    HV_Xi = FeasibleCHV(ref, flat_FXi, flat_CXi);

                    [v, V, lambda, d] = callGradient(config, flat_X0, HV_X0, flat_CX0, flat_Xi, HV_Xi, flat_CXi, u);
                    GSA_HVGrad = v';


                    %% Step
                    if config.use_interpolation
                        %% Step (CASwithoutNorm)
                        [~, ~, Xs, ~] = CASwithoutNorm(eta, X0, ref, ...
                                                        GSA_HVGrad, d, V, lambda, ...
                                                        Problem);
                    else
                        %% Flat step (no interpolation, with normalization)
                        % varepsilon = 1e-8;
                        % random_dir = rand(size(GSA_HVGrad));
                        N = size(X0, 2);
                        x0_flat = Flatten(X0.decs);
                        x1_flat = x0_flat + GSA_HVGrad .* eta .* repmat((Problem.upper-Problem.lower), 1, N);
                        x1_decs = Unflatten(x1_flat, N);
                        x1_decs = min(Problem.upper, max(Problem.lower, x1_decs));
                        Xs = Problem.Evaluation(x1_decs);
                    end
                end

                %% Update population
                GSA_Mixture = [Mixture,Xs];
                [Population,FrontNo,CrowdDis] = EnvironmentalSelection_NSGAII(GSA_Mixture,Problem.N);
                % Population = GSA_Mixture(Next);

                iter_counter = iter_counter + 1;
                alpha = Problem.FE/Problem.maxFE;
                eta = (1-alpha)*base_eta + alpha*goal_eta;
            end
        end
    end
end

function [base_eta, goal_eta] = getEtaBounds(config, D)
%GETETABOUNDS Compute base and goal eta from config and problem dimension
    switch config.eta_mode
        case 'adaptive'
            base_eta = sqrt(D);
            goal_eta = 1/sqrt(D);
        case 'constant_sqrtD'
            base_eta = sqrt(D);
            goal_eta = sqrt(D);
        case 'constant_invSqrtD'
            base_eta = 1/sqrt(D);
            goal_eta = 1/sqrt(D);
        case 'constant_one'
            base_eta = 1;
            goal_eta = 1;
        otherwise
            error('ConfigurableNSGA2CHVGSA:badEta', ...
                'Unknown eta_mode: %s', config.eta_mode);
    end
end

function refConstant = getRefConstant(refC, M, u)
%GETREFCONSTANT Compute reference constant from config
    if ischar(refC) || isstring(refC)
        if strcmp(refC, 'adaptive')
            H = max(1, getRefH(M, u));
            refConstant = 1 + 1/H;
        else
            error('ConfigurableNSGA2CHVGSA:badRefC', ...
                'Unknown refC value: %s', refC);
        end
    else
        refConstant = refC;
    end
end

function [v, V, lambda, d] = callGradient(config, flat_X0, HV_X0, flat_CX0, flat_Xi, HV_Xi, flat_CXi, u)
%CALLGRADIENT Dispatch to correct gradient method
    switch config.gradient_method
        case 'CGSA_n'
            [v, V, lambda, d] = CGSA_n(flat_X0, HV_X0, flat_CX0, flat_Xi, HV_Xi, flat_CXi, u);
        case 'CGSA'
            [v, V, lambda, d] = CGSA(flat_X0, HV_X0, flat_CX0, flat_Xi, HV_Xi, flat_CXi);
        otherwise
            error('ConfigurableNSGA2CHVGSA:badGradient', ...
                'Unknown gradient_method: %s', config.gradient_method);
    end
end
