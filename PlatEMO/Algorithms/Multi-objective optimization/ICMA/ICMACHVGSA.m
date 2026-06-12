classdef ICMACHVGSA < ALGORITHM
% <2022> <multi> <real/integer> <constrained>
% Indicator-based constrained multi-objective algorithm with C-HVGSA local search
%
%   Applies the current (NSGA-II-HVGSA default) C-HVGSA local search on top
%   of the ICMA baseline. The HVGSA configuration here is fixed and matches
%   the default produced by parseCHVGSAConfig() / generateCHVGSA():
%       eta_mode            = 'adaptive'   (sqrt(D) -> 1/sqrt(D))
%       use_normalization   = 'off'        (raw objective space)
%       use_expanded_front  = true
%       use_interpolation   = true         (CASwithoutNorm)
%       gradient_method     = 'CGSA_n'
%       U_mode              = 'random'     (random in [6,10])
%       sr_mode             = 'mean'
%       k_min               = 1
%       refC                = 'adaptive'   (1 + 1/H)
%       Qsize               = 50
%   Unlike ConfigurableNSGA2CHVGSA, ICMACHVGSA does not expose these as
%   parameters because ICMA is a baseline rather than an ablation target.
%
%   Supports heuristic initialization via the HID parameter so this class
%   participates in the BenchmarkPipeline shared initialization scheme.

%------------------------------- Reference --------------------------------
% J. Yuan, H. Liu, Y. Ong, and Z. He. Indicator-based evolutionary
% algorithm for solving constrained multi-objective optimization problems.
% IEEE Transactions on Evolutionary Computation, 2022, 26(2): 379-391.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    methods
        function main(Algorithm, Problem)
            %% Parameter setting (HID enables shared initial population)
            HID = Algorithm.ParameterSet("");

            %% HVGSA configuration (locked to NSGA-II-HVGSA default)
            base_eta = sqrt(Problem.D);
            goal_eta = 1/sqrt(Problem.D);
            Qsize    = 50;
            sr_mode  = 'mean';
            k_min    = 1;
            U_range  = [6, 10];

            %% Generate population (with optional heuristic initialization)
            Population = initPopulation(Problem, HID);
            Zmin       = min(Population.objs, [], 1);
            Fmin       = min(Population(all(Population.cons<=0, 2)).objs, [], 1);
            Archive    = Population;
            W          = UniformPoint(Problem.N, Problem.M);
            Ra         = 1;

            %% GSA history queue and adaptive step size
            iter_counter = 1;
            PopQ         = PopulationQueue(Qsize);
            eta          = base_eta;

            %% Optimization
            while Algorithm.NotTerminated(Archive)
                %% Push current Population into the GSA history
                PopQ.push(Population, iter_counter);

                %% EMOA step: ICMA reproduction (no environmental selection yet)
                Nt         = floor(Ra * Problem.N);
                MatingPool = [Population(randsample(Problem.N, Nt)), ...
                              Archive(randsample(length(Archive), Problem.N - Nt))];
                [Mate1, Mate2, Mate3] = Neighbor_Pairing_Strategy(MatingPool, Zmin);
                if rand > 0.5
                    Offspring = OperatorDE(Problem, Mate1, Mate2, Mate3);
                else
                    Offspring = OperatorDE(Problem, Mate1, Mate2, Mate3, {0.5,0.5,0.5,0.75});
                end

                %% GSA step: assemble candidate team and history
                Mixture   = [Population, Offspring];
                X0_source = Mixture;
                History   = X0_source;
                for i = 1 : PopQ.getSize()
                    History = [History, PopQ.get(i).pop];
                end
                [~, uniqueX0Ind]  = unique(X0_source.decs, 'rows');
                [~, uniqueHisInd] = unique(History.decs, 'rows');
                X0_source = X0_source(uniqueX0Ind);
                History   = History(uniqueHisInd);

                % Non-dominated set under CDP
                [TempFrontNo, ~] = NDSort(X0_source.objs, X0_source.cons, 1);
                ND_set           = X0_source(TempFrontNo == 1);

                % Expanded non-dominated set (default)
                [~, expanded_NDS] = Nondominance(ND_set, X0_source);
                ND_set            = expanded_NDS;

                U = randi(U_range, 1);
                [NeighborsArr, ~, X0_indices] = SelectNeighbors(ND_set, History, sr_mode, k_min, U);
                X0 = ND_set(X0_indices);
                u  = numel(X0);

                Xs = [];
                if ~isempty(NeighborsArr)
                    %% Adaptive reference point (raw space)
                    H           = max(1, getRefH(Problem.M, numel(ND_set)));
                    refConstant = 1 + 1/H;
                    ref         = BetterRefGetter(ND_set.objs, refConstant);

                    %% Gradient via CGSA_n
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

                    [v, V, lambda, d] = CGSA_n(flat_X0, HV_X0, flat_CX0, ...
                                               flat_Xi, HV_Xi, flat_CXi, u);
                    GSA_HVGrad = v';

                    %% Interpolative adaptive step (raw space)
                    [~, ~, Xs, ~] = CASwithoutNorm(eta, X0, ref, ...
                                                  GSA_HVGrad, d, V, lambda, Problem);
                end

                %% Update Zmin / Fmin with all newly generated solutions
                if ~isempty(Xs)
                    Fmin = min([Fmin; ...
                                Offspring(all(Offspring.cons<=0, 2)).objs; ...
                                Xs(all(Xs.cons<=0, 2)).objs], [], 1);
                    Zmin = min([Zmin; Offspring.objs; Xs.objs], [], 1);
                    Combined = [Population, Offspring, Xs, Archive];
                else
                    Fmin = min([Fmin; ...
                                Offspring(all(Offspring.cons<=0, 2)).objs], [], 1);
                    Zmin = min([Zmin; Offspring.objs], [], 1);
                    Combined = [Population, Offspring, Archive];
                end

                %% ICMA environmental selection over EMOA + GSA outputs
                [Population, Archive] = ICMA_Update(Combined, Problem.N, W, Zmin, Fmin);

                Ra = 1 - Problem.FE / Problem.maxFE;

                %% Advance eta schedule
                iter_counter = iter_counter + 1;
                alpha = Problem.FE / Problem.maxFE;
                eta   = (1 - alpha) * base_eta + alpha * goal_eta;
            end
        end
    end
end
