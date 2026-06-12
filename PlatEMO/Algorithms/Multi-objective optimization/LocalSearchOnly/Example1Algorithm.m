classdef Example1Algorithm < ALGORITHM
    methods
        function main(Algorithm,Problem)
            %% Parameter setting
            rng(2222);

            %% Misc parameters
            eta = 1;
            slack = 1; % slack in CGSA
            refC = 1.2; % Reference constant
            norm_eps = 1e-6;
            
            %% Generate random population (EMOA)
            Initial_Decs = [1,3;3,1;5,-2;6,-1;9,1];
            Population = Problem.Evaluation(Initial_Decs);


            %% Visualization struct
            viz_data = struct();
            iter_counter = 1;
            viz_data.Populations = {};
            viz_data.Iterations = {};
            viz_data.Directions = {};
            viz_data.Neighbors = {};
            viz_data.Trajectories = {};
            viz_data.Reference = {};

            while Algorithm.NotTerminated(Population)
                viz_data.Populations{iter_counter} = Population;
                viz_data.Iterations{iter_counter} = iter_counter;

                %% Generating neighbors
                U = numel(Population);
                X0 = Population;
    
                Neighbors = GenerateArtificialNeighbors(X0, Problem, "radial");
                
                cell_objs = cellfun(@(c) c.objs, Neighbors, 'UniformOutput', false);
                concat_objs = vertcat(cell_objs{:}, X0.objs);
    
                ref = RefGetter(concat_objs, refC);
                viz_data.Reference{iter_counter} = ref;
                
                disp("ref");
                FormatMatrix("% .5f", ref);
                
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
    
                slack = 0;
                [v, V, lambda, d] = CGSA(flat_X0, HV_X0, flat_CX0, flat_Xi, HV_Xi, flat_CXi);
                GSA_HVGrad = v';

                disp(v);
                % disp(GSA_HVGrad);
                % return

    
                [tps, tes, Xs, trajectory] = CASwithoutNorm(...
                                                    eta, X0, ref, ...
                                                    GSA_HVGrad, d, V, lambda, ...
                                                    Problem);
    
                viz_data.Neighbors{iter_counter} = Neighbors;
                viz_data.Directions{iter_counter} = GSA_HVGrad;
                viz_data.Trajectories{iter_counter} = trajectory;

                Population = Xs;

                flat_FX1 = Flatten(Xs.objs);
                flat_CX1 = Flatten(Xs.cons);
                disp(flat_FX1);
                HV_X1 = FeasibleCHV(ref, flat_FX1, flat_CX1);
                disp(HV_X1);


                iter_counter = iter_counter + 1;

                if Problem.FE >= Problem.maxFE
                    disp(viz_data);
                    VisualizeExample1(viz_data, Problem);
                    return
                end
            end
        end
    end
end


