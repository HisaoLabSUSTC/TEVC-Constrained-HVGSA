classdef ConfigurableHVGA < ALGORITHM
% <multi> <real/integer/label/binary/permutation> <constrained/none>
% Configurable standalone HVGA (pure local search via forward-difference)
%
%   A standalone gradient-based local search algorithm that computes the
%   hypervolume indicator gradient via forward finite differences in the
%   decision space and performs gradient ascent.  Unlike HVGSA, this method
%   does not maintain any historical queues and recomputes the gradient
%   from scratch each generation.
%
%   Usage:
%     % Default (eta=1e-3, delta=1e-6, auto reference point)
%     platemo('algorithm', {@ConfigurableHVGA, struct()}, ...)
%
%     % Fixed reference point
%     platemo('algorithm', {@ConfigurableHVGA, struct('ref', [120 120])}, ...)
%
%     % Custom step-size and perturbation
%     platemo('algorithm', {@ConfigurableHVGA, struct('eta', 1e-2, 'delta', 1e-5)}, ...)

    methods
        function main(Algorithm, Problem)
            %% Parse config and HID
            [configIn, HID] = Algorithm.ParameterSet(struct(), "");
            config = parseHVGAConfig(configIn);

            %% Set save name
            variantName = config2name_HVGA(config);
            Algorithm.SetSaveName(variantName);

            %% Parameters from config
            eta   = config.eta;
            delta = config.delta;

            %% Generate population (with optional heuristic initialization)
            Population = initPopulation(Problem, HID);

            %% Problem dimensions
            M = Problem.M;   % number of objectives
            D = Problem.D;   % number of decision variables
            N = numel(Population);

            %% Reference point for HV tracking (population-level)
            if isempty(config.ref)
                ideal = min(Population.objs, [], 1);
                nadir = max(Population.objs, [], 1);
                ref = ideal + (1 + 1/max(getRefH(M, N), 1)) * (nadir - ideal);
            else
                ref = config.ref;
            end

            %% Variable ranges for relative perturbation
            ranges = Problem.upper - Problem.lower;

            %% Counter
            global HV_counter;
            HV_counter = 0;
            iter_counter = 1;
            max_iter = 2000;

            %% Optimization
            while Algorithm.NotTerminated(Population)
                %% Reference point for gradient computation
                if isempty(config.ref)
                    ideal = min(Population.objs, [], 1);
                    nadir = max(Population.objs, [], 1);
                    % ref = ideal + (1 + 1/max(getRefH(M, N), 1)) * (nadir - ideal);
                    ref = ideal + 1.2 * (nadir - ideal);
                else
                    ref = config.ref;
                end

                %% Current population data
                base_decs = Population.decs;   % N x D
                base_objs = Population.objs;   % N x M
                base_cons = Population.cons;   % N x P
                P = size(base_cons, 2);

                %% Base hypervolume
                flat_base_objs = Flatten(base_objs);
                flat_base_cons = Flatten(base_cons);
                HV_base = FeasibleCHV(ref, flat_base_objs, flat_base_cons);

                %% --- Forward-difference gradient computation ---
                %  Absolute perturbation per variable (relative to range)
                delta_abs = delta * ranges;   % 1 x D

                %  Build all N*D perturbed individuals
                all_pert_decs = zeros(N * D, D);
                for i = 1:N
                    for j = 1:D
                        idx = (i - 1) * D + j;
                        all_pert_decs(idx, :) = base_decs(i, :);
                        all_pert_decs(idx, j) = all_pert_decs(idx, j) + delta_abs(j);
                    end
                end
                all_pert_decs = min(Problem.upper, max(Problem.lower, all_pert_decs));

                %  Evaluate all perturbed individuals  (N*D function evaluations)
                all_pert = Problem.Evaluation(all_pert_decs);

                %  Build perturbed-population objective/constraint matrices
                flat_pert_objs = zeros(N * D, N * M);
                flat_pert_cons = zeros(N * D, N * P);
                for i = 1:N
                    for j = 1:D
                        idx = (i - 1) * D + j;
                        tmp_objs      = base_objs;
                        tmp_objs(i,:) = all_pert(idx).objs;
                        tmp_cons      = base_cons;
                        tmp_cons(i,:) = all_pert(idx).cons;
                        flat_pert_objs(idx,:) = Flatten(tmp_objs);
                        flat_pert_cons(idx,:) = Flatten(tmp_cons);
                    end
                end

                %  Batch hypervolume computation  (N*D HV computations)
                HV_pert = FeasibleCHV(ref, flat_pert_objs, flat_pert_cons);

                %  Assemble gradient (N x D)
                grad = zeros(N, D);
                for i = 1:N
                    for j = 1:D
                        idx = (i - 1) * D + j;
                        actual_delta = all_pert_decs(idx, j) - base_decs(i, j);
                        if abs(actual_delta) < eps
                            grad(i, j) = 0;
                        else
                            grad(i, j) = (HV_pert(idx) - HV_base) / max(actual_delta, 1e-6);
                        end
                    end
                end

                %% Normalize gradient per individual
                grad_norms = vecnorm(grad, 2, 2) + eps;
                grad_normalized = grad ./ grad_norms;
                

                %% Gradient ascent step
                new_decs = base_decs + eta * grad_normalized;
                new_decs = min(Problem.upper, max(Problem.lower, new_decs));

                %  Evaluate new population  (N function evaluations)
                Population = Problem.Evaluation(new_decs);

                iter_counter = iter_counter + 1;
                if iter_counter > max_iter
                    FE_counter = Problem.FE;
                    save('HV_counter.mat', 'HV_counter');
                    save('FE_counter.mat', 'FE_counter');
                    Problem.FE = 1e8;
                end
            end
        end
    end
end
