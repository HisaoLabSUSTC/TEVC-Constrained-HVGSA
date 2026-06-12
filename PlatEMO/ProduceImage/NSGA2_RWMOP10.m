Problem = @RWMOP27;
problemName = func2str(Problem);


%% GOOD: 10, 16, 18, 25, 26, 27
N = 5;
FE = 500;
run_num = 2;

%% Generate (or load) a deterministic initial population
HS_dir = './Info/InitialPopulation';
generateInitialPopulations({Problem}, N, run_num, HS_dir, {problemName});
HID_file = fullfile(HS_dir, sprintf('HS-%s_%d.mat', problemName, run_num));

%% Compute reference point from the stored reference PF (not fixed)
[~, ideal, nadir] = loadReferencePF(problemName);
ref_pf = ideal + 1.2 * (nadir - ideal);  % 10% margin beyond nadir
fprintf('Reference point (from nadir): [%s]\n', num2str(ref_pf, '%.4f '));

%% Generate algorithm spec
algorithm = {@NSGAIIwH, HID_file};

%% Run
platemo('problem', Problem, 'N', N, ...
        'maxFE', FE, 'algorithm', algorithm, 'save', 1e8, 'run', run_num);

%% Visualize — reconstruct viz_data from PlatEMO-saved result
PROBLEM = Problem();
algName = 'NSGAIIwH';

dataFile = fullfile('Data', algName, ...
    sprintf('%s_%s_M%d_D%d_%d.mat', algName, class(PROBLEM), PROBLEM.M, PROBLEM.D, run_num));

data = load(dataFile);
result = data.result;  % Nx2 cell: {FE, Population}

nGen = size(result, 1);
viz_data = struct();
viz_data.Populations = result(:,2)';
viz_data.Iterations = num2cell(1:nGen);
viz_data.Ref = ref_pf;
viz_data.Hypervolume = cell(1, nGen);
for i = 1:nGen
    pop = result{i, 2};
    viz_data.Hypervolume{i} = FeasibleCHV(ref_pf, Flatten(pop.objs), Flatten(pop.cons));
end

% VisualizeRWMOP(viz_data, problemName);
VisualizeRWMOP_Backward(viz_data, problemName);

% filename = sprintf('ProduceImage/images/NSGA2_obj_%s.png', func2str(Problem));
% exportgraphics(gcf, filename, 'Resolution', 300);
% close(gcf);
% 
% filename = sprintf('ProduceImage/images/NSGA2_dec_%s.png', func2str(Problem));
% exportgraphics(gcf, filename, 'Resolution', 300);
% close(gcf);