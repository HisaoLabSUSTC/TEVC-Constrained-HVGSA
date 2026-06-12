classdef CMOEACDCHVGSA < ALGORITHM
% <2025> <multi/many> <real/binary/permutation><constrained/none>
% Constraint-Pareto dominance and diversity enhancement strategy based CMOEA
% with C-HVGSA local search
%
%   Applies the current (NSGA-II-HVGSA default) C-HVGSA local search on top
%   of the CMOEA-CD baseline. The HVGSA configuration here is fixed and
%   matches the default produced by parseCHVGSAConfig() / generateCHVGSA():
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
%   Unlike ConfigurableNSGA2CHVGSA, CMOEACDCHVGSA does not expose these as
%   parameters because CMOEA-CD is a baseline rather than an ablation target.
%
%   Supports heuristic initialization via the HID parameter so this class
%   participates in the BenchmarkPipeline shared initialization scheme.

%------------------------------- Reference --------------------------------
% Z. Liu, F. Han, Q. Ling, H. Han, and J. Jiang. Constraint-Pareto
% dominance and diversity enhancement strategy based evolutionary algorithm
% for solving constrained multiobjective optimization problems. IEEE
% Transactions on Evolutionary Computation, 2025.
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
            % Environmental selection variants inherited from CMOEA-CD, fixed
            % at the baseline default (SPEA2) since HVGSA is the ablation focus.
            e1 = 1;
            e2 = 1;
            Ns = floor(Problem.N / 3);

            %% HVGSA configuration (locked to NSGA-II-HVGSA default)
            base_eta = sqrt(Problem.D);
            goal_eta = 1/sqrt(Problem.D);
            Qsize    = 50;
            sr_mode  = 'mean';
            k_min    = 1;
            U_range  = [6, 10];

            %% Generate population (with optional heuristic initialization)
            Population = initPopulation(Problem, HID);
            FA        = [];
            DA        = [];
            FEA       = Population;
            Offspring = Population;
            zmin      = min(Population.objs, [], 1) - 1e-6;

            %% GSA history queue and adaptive step size
            iter_counter = 1;
            PopQ         = PopulationQueue(Qsize);
            eta          = base_eta;

            %% Optimization
            while Algorithm.NotTerminated(FEA)
                %% Push current Offspring (the rolling candidate pool) into GSA history
                PopQ.push(Offspring, iter_counter);

                %% CMOEA-CD archive updates using prior iteration's Offspring
                zmin = min(zmin, min(Offspring.objs, [], 1) - 1e-6);
                FA   = ForwardExplorationArchive(FA, Offspring, zmin, Ns, e1);
                DA   = DiversityEnhancementArchive(DA, Offspring, zmin, Ns);
                FEA  = FeasibilityExploitationArchive(FEA, Offspring, Problem.N, e2);

                %% EMOA step: reproduce from FA, DA, FEA
                Pop1 = FA;
                Pop2 = DA;
                Pop3 = FEA(unidrnd(length(FEA), [1, floor(Problem.N/3)]));
                MatingPool_Pop1_1 = randperm(length(Pop1));
                MatingPool_Pop1_2 = randperm(length(Pop1));
                MatingPool_Pop2_1 = randperm(length(Pop2));
                MatingPool_Pop2_2 = randperm(length(Pop2));
                MatingPool_Pop3_1 = randperm(length(Pop3));
                MatingPool_Pop3_2 = randperm(length(Pop3));
                if rand() < 0.5
                    Offspring1 = OperatorDE(Problem, Pop1, Pop1(MatingPool_Pop1_1), Pop1(MatingPool_Pop1_2), {1,0.5,1,1});
                    Offspring2 = OperatorDE(Problem, Pop2, Pop2(MatingPool_Pop2_1), Pop2(MatingPool_Pop2_2), {1,0.5,1,1});
                    Offspring3 = OperatorDE(Problem, Pop3, Pop3(MatingPool_Pop3_1), Pop3(MatingPool_Pop3_2), {1,0.5,1,1});
                else
                    Offspring1 = OperatorGA(Problem, Pop1(MatingPool_Pop1_1), {1,20,1,1});
                    Offspring2 = OperatorGA(Problem, Pop2(MatingPool_Pop2_1), {1,20,1,1});
                    Offspring3 = OperatorGA(Problem, Pop3(MatingPool_Pop3_1), {1,20,1,1});
                end
                NewOffspring = [Offspring1, Offspring2, Offspring3];

                %% GSA step: assemble candidate team and history
                X0_source = NewOffspring;
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

                %% Merge Xs into the rolling Offspring for next iteration's archives
                if ~isempty(Xs)
                    Offspring = [NewOffspring, Xs];
                else
                    Offspring = NewOffspring;
                end

                %% Advance eta schedule
                iter_counter = iter_counter + 1;
                alpha = Problem.FE / Problem.maxFE;
                eta   = (1 - alpha) * base_eta + alpha * goal_eta;
            end
        end
    end
end
