% problem = @ZDT2;
% problems = {@ZDT2, @ZDT3, @ZDT4, @ZDT6};
problems = {@EqCo6};
archive_size = 10;
N = 100;
% FE_moea = 3000;
% FE_moeas = [3000, 4000, 5000, 6000];
% FE_moeas = [7000];
% FE_moeas = [4000];
FE_moeas = [1100];
GSA_iters = 10;
AGSA_iters = 2;
% with_n = 0;
with_ns = [0, 1];

rng('shuffle');
s = rng
% s = 1978638488; % FE = 7000
% s = 1995463634; % FE = 4000
s = 1995587201;

for problem = problems
    problem = problem{:};
    for FE_moea = FE_moeas
        for with_n = with_ns
            if with_n == 1
                eta_fixed = 0.1;
                eta_0 = 1;
            else
                eta_fixed = 0.1;
                eta_0 = 1;
            end


            if strcmp(func2str(problem), "ZDT3")
                fixed_ref = [1.2, 2.5];
            elseif strcmp(func2str(problem), "ZDT2")
                fixed_ref = [1.4, 1.4];
            elseif strcmp(func2str(problem), "ZDT4")
                fixed_ref = [1.2, 10];
            elseif strcmp(func2str(problem), "ZDT6")
                fixed_ref = [1.2, 5];
            elseif strcmp(func2str(problem), "ZDT1")
                fixed_ref = [1.2, 2.0];
            elseif strcmp(func2str(problem), "UF2")
                fixed_ref = [1.5, 1.5];
            elseif strcmp(func2str(problem), "UF4")
                fixed_ref = [1.3, 1.3];    
            elseif strcmp(func2str(problem), "EqCo6")
                fixed_ref = [1.4, 1.4];    
            end


            fixed_ref_x = fixed_ref(1);
            fixed_ref_y = fixed_ref(2);


            %% === Run algorithm and save data ===
            platemo('problem', problem, ...
                    'N', N, ...
                    'maxFE', 1e10, ...
                    'algorithm', {@NSGA2NoExtraHVAngel, archive_size,N, ...
                    FE_moea,GSA_iters,eta_fixed,AGSA_iters,eta_0,fixed_ref_x, fixed_ref_y, with_n, s});

            %% === Load data and visualize ===
            PROBLEM = problem();
            filename = sprintf('./Visualization/Data/%s_FE%d.mat', class(PROBLEM), FE_moea);
            VisualizeNoExtraHV(filename, PROBLEM);
        end
    end
end
