classdef CBOPAlgorithm < ALGORITHM
    methods
        function main(Algorithm,Problem)
            %% Parameter setting
            rng(2222);

            %% Misc parameters
            eta = 0.002;
            slack = 0; % slack in CGSA
            refC = 1.2; % Reference constant
            norm_eps = 1e-6;
            
            %% Generate random population (EMOA)
            Initial_Decs = [2.4,2.6;4.45,2.7;5.05,2.45;6.05,2.7;7.02,2.66];
            % Initial_Decs = [0.05,-0.447;2.43,0.482;5.05,-0.203;7.88,-0.37;9.95,-0.14];
            Population = Problem.Evaluation(Initial_Decs);

            %% Visualization struct
            viz_data = struct();
            iter_counter = 1;
            viz_data.Populations = {};
            viz_data.Iterations = {};
            viz_data.Hypervolume = {};

            [~, ref_pf] = GetPFnRef(Problem);
            ref_pf = [120, 120];
            
            
            while Algorithm.NotTerminated(Population)
                viz_data.Populations{iter_counter} = Population;
                viz_data.Iterations{iter_counter} = iter_counter;

                flat_objs = Flatten(Population.objs);
                flat_cons = Flatten(Population.cons);
                pop_hv = FeasibleCHV(ref_pf, flat_objs, flat_cons);
                viz_data.Hypervolume{iter_counter} = pop_hv;


                %% Generating neighbors
                U = numel(Population);
                X0 = Population;
                u = numel(X0);
    
                Neighbors = GenerateArtificialNeighbors(X0, Problem, "radial");
                
                cell_objs = cellfun(@(c) c.objs, Neighbors, 'UniformOutput', false);
                concat_objs = vertcat(cell_objs{:}, X0.objs);
    
                % ref = RefGetter(concat_objs, refC);
                ref = [120, 120];
                
                flat_X0 = Flatten(X0.decs);
                flat_FX0 = Flatten(X0.objs);
                flat_CX0 = Flatten(X0.cons);
                cell_flat_decs = cellfun(@(c) Flatten(c.decs), Neighbors, 'UniformOutput', false);
                flat_Xi = vertcat(cell_flat_decs{:});
                cell_flat_objs = cellfun(@(c) Flatten(c.objs), Neighbors, 'UniformOutput', false);
                flat_FXi = vertcat(cell_flat_objs{:});
                cell_flat_cons = cellfun(@(c) Flatten(c.cons), Neighbors, 'UniformOutput', false);
                flat_CXi = vertcat(cell_flat_cons{:});
    
                HV_X0 = FeasibleCHV(ref, flat_FX0, flat_CX0);
                HV_Xi = FeasibleCHV(ref, flat_FXi, flat_CXi);
    
                [v, V, lambda, d] = CGSA_n(flat_X0, HV_X0, flat_CX0, flat_Xi, HV_Xi, flat_CXi, u);
                GSA_HVGrad = v';

                flat_Xs = flat_X0 + eta * GSA_HVGrad;
                Xs_decs = Unflatten(flat_Xs, u);
                Xs = Problem.Evaluation(Xs_decs);

                Population = Xs;

                iter_counter = iter_counter + 1;

                if Problem.FE >= Problem.maxFE
                    viz_data.Populations{iter_counter} = Population;
                    viz_data.Iterations{iter_counter} = iter_counter;
                    flat_objs = Flatten(Population.objs);
                    flat_cons = Flatten(Population.cons);
                    pop_hv = FeasibleCHV(ref_pf, flat_objs, flat_cons);
                    viz_data.Hypervolume{iter_counter} = pop_hv;
                    viz_data.Ref = ref_pf;
                    viz_name = sprintf("Visualization/%s_%d.mat", class(Problem), Problem.maxFE);
                    save(viz_name, "viz_data");
                    % VisualizeCBOP(viz_data, Problem);
                    return
                end
            end
        end
    end
end


