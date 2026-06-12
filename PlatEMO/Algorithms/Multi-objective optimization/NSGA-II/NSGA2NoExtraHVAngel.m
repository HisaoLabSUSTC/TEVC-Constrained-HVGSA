classdef NSGA2NoExtraHVAngel < ALGORITHM
    methods
        function main(Algorithm, Problem)
            %% === Parameters ===
            [archive_size,N,FE_moea,GSA_iters,eta_fixed,AGSA_iters,eta_0,fixed_ref_x, fixed_ref_y, with_n,seed] = ...
            Algorithm.ParameterSet(10,50,5000,10,0.05,2,1,1.2,1.2,1);
            rng(seed);

            %% === Initialization ===
            Population = Problem.Initialization();
            [~, FrontNo, CrowdDis] = EnvironmentalSelection(Population, Problem.N);

            fixed_ref = [fixed_ref_x, fixed_ref_y];
            Qsize = 10;
            iter_counter = 1;

            PopQ = PopulationQueue(Qsize);
            HVQ = PopulationQueue(Qsize); MOEA_HVFE = 0;

            PopQ.push(Population, iter_counter);
            flat_fs = Flatten(Population.objs);
            flat_cs = Flatten(Population.cons);
            Current_HV = FeasibleCHV(fixed_ref, flat_fs, flat_cs); MOEA_HVFE = MOEA_HVFE + 1;
            HVQ.push(Current_HV, iter_counter);
            iter_counter = iter_counter + 1;

            %% Visualization data
            viz_data.TRAJECTORY.ITER = {};
            viz_data.TRAJECTORY.POP = {};
            viz_data.N = Problem.N;

            %% === Stage 1: NSGA-II Evolution ===
            while Problem.FE < FE_moea
                MatingPool = TournamentSelection(2, Problem.N, FrontNo, -CrowdDis);
                Offspring = OperatorGA(Problem, Population(MatingPool));
                [Population, FrontNo, CrowdDis] = EnvironmentalSelection_NSGAII([Population, Offspring], Problem.N);

                flat_fs = Flatten(Population.objs);
                flat_cs = Flatten(Population.cons);
                Current_HV = FeasibleCHV(fixed_ref, flat_fs, flat_cs); MOEA_HVFE = MOEA_HVFE + 1;

                PopQ.push(Population, iter_counter);
                HVQ.push(Current_HV, iter_counter);
                iter_counter = iter_counter + 1;
            end

            viz_data.MOEA_POP = Population;
            viz_data.MOEA_ITER = iter_counter;
            viz_data.MOEA_FE = Problem.FE;
            viz_data.MOEA_HVFE = MOEA_HVFE;

            linear_FE = 0; linear_HVFE = 0;
            adaptive_FE = 0; adaptive_HVFE = 0;
            GSA_POPQ = PopQ.copy();
            AGSA_POPQ = PopQ.copy();
            GSA_HVQ = HVQ.copy();
            AGSA_HVQ = HVQ.copy();

            gsa_iter_counter = iter_counter;
            %% === Stage 2: Linear HV-GSA ===
            for k = 1:GSA_iters
                X0 = GSA_POPQ.get(1).pop;
                HV0 = GSA_HVQ.get(1).pop;
                u = size(X0, 2);

                cell_decs = cell(1, GSA_POPQ.getSize - 1);
                cell_objs = cell(1, GSA_POPQ.getSize - 1);
                cell_cons = cell(1, GSA_POPQ.getSize - 1);
                HVis = zeros(GSA_POPQ.getSize - 1, 1);

                for i = 2:GSA_POPQ.getSize()
                    Xi = GSA_POPQ.get(i).pop;
                    cell_decs{i - 1} = Xi.decs;
                    cell_objs{i - 1} = Xi.objs;
                    cell_cons{i - 1} = Xi.cons;
                    HVis(i - 1) = GSA_HVQ.get(i).pop;
                end

                flat_X0 = Flatten(X0.decs);
                flat_FX0 = Flatten(X0.objs);
                flat_CX0 = Flatten(X0.cons);

                cell_flat_decs = cellfun(@(c) Flatten(c), cell_decs, 'UniformOutput', false);
                cell_flat_objs = cellfun(@(c) Flatten(c), cell_objs, 'UniformOutput', false);
                cell_flat_cons = cellfun(@(c) Flatten(c), cell_cons, 'UniformOutput', false);

                flat_Xi = vertcat(cell_flat_decs{:});
                flat_FXi = vertcat(cell_flat_objs{:});
                flat_CXi = vertcat(cell_flat_cons{:});

                HV_X0 = HV0;
                HV_Xi = HVis;

                if with_n == 1
                    [v, V, lambda, d] = CGSA_n(flat_X0, HV_X0, flat_CX0, flat_Xi, HV_Xi, flat_CXi, u);
                else
                    [v, V, lambda, d] = CGSA(flat_X0, HV_X0, flat_CX0, flat_Xi, HV_Xi, flat_CXi);
                end
                GSA_HVGrad = v';

                linear_startFE = Problem.FE;
                %% Linear Gradient Ascent
                varepsilon = 1e-6;
                random_dir = rand(size(GSA_HVGrad));
                flat_X1 = flat_X0 + GSA_HVGrad * eta_fixed + varepsilon * random_dir;
                X1_decs = Unflatten(flat_X1, u);
                X1 = Problem.Evaluation(X1_decs);
                viz_data.TRAJECTORY.ITER{end+1} = gsa_iter_counter + 1;
                viz_data.TRAJECTORY.POP{end+1} = X1;
                Xs = X1;
                linear_FE = linear_FE + Problem.FE - linear_startFE;


                %% Update population
                Population = Xs(end-u+1:end);
                flat_fs = Flatten(Population.objs);
                flat_cs = Flatten(Population.cons);
                Current_HV = FeasibleCHV(fixed_ref, flat_fs, flat_cs); linear_HVFE = linear_HVFE + 1;

                gsa_iter_counter = gsa_iter_counter + 1;
                GSA_POPQ.push(Population, gsa_iter_counter);
                GSA_HVQ.push(Current_HV, gsa_iter_counter);
            end

            viz_data.GSA_POP = Population;
            viz_data.GSA_ITER = gsa_iter_counter;
            
            agsa_iter_counter = iter_counter;
            %% === Stage 3: Adaptive HV-GSA ===
            for k = 1:AGSA_iters
                X0 = AGSA_POPQ.get(1).pop;
                HV0 = AGSA_HVQ.get(1).pop;
                u = size(X0, 2);

                cell_decs = cell(1, AGSA_POPQ.getSize - 1);
                cell_objs = cell(1, AGSA_POPQ.getSize - 1);
                cell_cons = cell(1, AGSA_POPQ.getSize - 1);
                HVis = zeros(AGSA_POPQ.getSize - 1, 1);

                for i = 2:AGSA_POPQ.getSize()
                    Xi = AGSA_POPQ.get(i).pop;
                    cell_decs{i - 1} = Xi.decs;
                    cell_objs{i - 1} = Xi.objs;
                    cell_cons{i - 1} = Xi.cons;
                    HVis(i - 1) = AGSA_HVQ.get(i).pop;
                end

                flat_X0 = Flatten(X0.decs);
                flat_FX0 = Flatten(X0.objs);
                flat_CX0 = Flatten(X0.cons);

                cell_flat_decs = cellfun(@(c) Flatten(c), cell_decs, 'UniformOutput', false);
                cell_flat_objs = cellfun(@(c) Flatten(c), cell_objs, 'UniformOutput', false);
                cell_flat_cons = cellfun(@(c) Flatten(c), cell_cons, 'UniformOutput', false);

                flat_Xi = vertcat(cell_flat_decs{:});
                flat_FXi = vertcat(cell_flat_objs{:});
                flat_CXi = vertcat(cell_flat_cons{:});

                HV_X0 = HV0;
                HV_Xi = HVis;

                if with_n == 1
                    [v, V, lambda, d] = CGSA_n(flat_X0, HV_X0, flat_CX0, flat_Xi, HV_Xi, flat_CXi, u);
                else
                    [v, V, lambda, d] = CGSA(flat_X0, HV_X0, flat_CX0, flat_Xi, HV_Xi, flat_CXi);
                end
                GSA_HVGrad = v';

                %% Interpolation Gradient Ascent
                adaptive_startFE = Problem.FE;
                ref = fixed_ref;
                [~, tested_etas, Xs, ~] = CASwithoutNorm( eta_0, X0, ref, ...
                                                GSA_HVGrad, d, V, lambda, ...
                                                Problem);
                Xs = Xs(end-Problem.N+1:end);
                viz_data.TRAJECTORY.ITER{end+1} = agsa_iter_counter + 1;
                viz_data.TRAJECTORY.POP{end+1} = Xs;
                adaptive_HVFE = adaptive_HVFE + numel(tested_etas);
                adaptive_FE = adaptive_FE + Problem.FE - adaptive_startFE;


                %% Update population
                Population = Xs(end-u+1:end);
                flat_fs = Flatten(Population.objs);
                flat_cs = Flatten(Population.cons);
                Current_HV = FeasibleCHV(fixed_ref, flat_fs, flat_cs);

                agsa_iter_counter = agsa_iter_counter + 1;
                AGSA_POPQ.push(Population, agsa_iter_counter);
                AGSA_HVQ.push(Current_HV, agsa_iter_counter);
            end


            %% === Save Results for Visualization ===
            viz_data.AGSA_POP = Population;
            viz_data.AGSA_ITER = agsa_iter_counter;
            viz_data.REFERENCE = fixed_ref;

            viz_data.GSA_FE = linear_FE;
            viz_data.GSA_HVFE = linear_HVFE;
            viz_data.AGSA_FE = adaptive_FE;
            viz_data.AGSA_HVFE = adaptive_HVFE;
            
            
            if with_n == 1
                n_string = "CGSAn";
            else
                n_string = "CGSA";
            end

            viz_data.NAME = sprintf("%s_%d_%d_%.4f_%.4f_%s.eps", ...
                class(Problem),archive_size,FE_moea,eta_fixed,eta_0,n_string);

            outdir = './Visualization/Data';
            if ~exist(outdir, 'dir')
                mkdir(outdir);
            end

            filename = sprintf('%s/%s_FE%d.mat', outdir, class(Problem), FE_moea);
            save(filename, 'viz_data', '-v7.3');

            fprintf('[NSGA2NoExtraHVAngel] Saved data to %s\n', filename);
        end
    end
end
