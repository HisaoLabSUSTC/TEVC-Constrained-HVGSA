Problem = @RWMOP10;
problemName = func2str(Problem);

%% GOOD: 10, 16, 18, 25, 26, 27
N = 5;
FE = 1000000;
run_num = 12;
max_iter = 2000;

%% Generate (or load) a deterministic initial population
HS_dir = './Info/InitialPopulation';
generateInitialPopulations({Problem}, N, run_num, HS_dir, {problemName});
HID_file = fullfile(HS_dir, sprintf('HS-%s_%d.mat', problemName, run_num));

%% Compute reference point from the stored reference PF (not fixed)
[~, ideal, nadir] = loadReferencePF(problemName);
ref_pf = ideal + 1.2 * (nadir - ideal);  % 10% margin beyond nadir
fprintf('Reference point (from nadir): [%s]\n', num2str(ref_pf, '%.4f '));

%% Generate algorithm spec
algorithmConfig = struct('eta', 1e-3, 'ref', ref_pf);
algorithm = generateHVGA(algorithmConfig);
algorithm{end+1} = HID_file;

%% Run
platemo('problem', Problem, 'N', N, ...
        'maxFE', FE, 'algorithm', algorithm, 'save', 1e8, 'run', run_num);

%% Visualize — reconstruct viz_data from PlatEMO-saved result
PROBLEM = Problem();
algName = config2name_HVGA(parseHVGAConfig(algorithmConfig));

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

%% ---- Optimization statistics for the legend box (optional) ----
% Total FE is available from the saved result's last row (first column is FE).
total_FE     = [load('FE_counter.mat').FE_counter];
% Fill in the numbers you want shown; leave empty ([]) to hide a row.
total_HVeval = [load('HV_counter.mat').HV_counter];   % e.g., total_HVeval = 1234;
total_time   = [data.metric.runtime];   % e.g., total_time   = 12.34;   (seconds)

% VisualizeRWMOP(viz_data, problemName);
VisualizeRWMOP_Backward(viz_data, problemName, ...
    'Problem',     PROBLEM, ...      % enables feasibility patch + decision-box boundary
    'GridSize',    200, ...
    'TotalFE',     total_FE, ...
    'TotalHVEval', total_HVeval, ...
    'TotalTime',   total_time, ...
    'refp', ref_pf);


imgDir = './ProduceImage/images';
if ~exist(imgDir, 'dir'), mkdir(imgDir); end

fig1 = figure(1); ax1 = fig1.CurrentAxes;
title(ax1, 'RCM10 Decision Space');
filename = sprintf('%s_HVGA_dec_%d.png', problemName, max_iter);
exportgraphics(fig1, fullfile(imgDir, filename), 'Resolution', 500);

fig2 = figure(2); ax2 = fig2.CurrentAxes;
title(ax2, 'RCM10 Objective Space');
filename = sprintf('%s_HVGA_obj_%d.png', problemName, max_iter);
exportgraphics(fig2, fullfile(imgDir, filename), 'Resolution', 500);

close(fig1); close(fig2);

% filename = sprintf('ProduceImage/images/HVGA_obj_%s.png', func2str(Problem));
% exportgraphics(gcf, filename, 'Resolution', 300);
% close(gcf);
%
% filename = sprintf('ProduceImage/images/HVGA_dec_%s.png', func2str(Problem));
% exportgraphics(gcf, filename, 'Resolution', 300);
% close(gcf);
