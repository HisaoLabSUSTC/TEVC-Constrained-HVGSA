%% BenchmarkPipeline - Benchmark pipeline for C-HVGSA on RWMOP1-50
%
%   Modular benchmark pipeline for constrained multi-objective optimization
%   using the RWMOP1-50 problem suite.
%
%   Key design choices:
%     - Problems are uniquely identified by handle alone (@RWMOP1), no M/D/ID needed.
%     - Two problem classes based on feasibility:
%         Feasible (RWMOP1-35, RWMOP50): metric = normalized HV, speed = AUC of normalized HV
%         Infeasible (RWMOP36-49): metric = average CV, speed = -AUC of average CV
%     - Normalization for feasible problems uses reference PF ideal/nadir.
%     - HV reference point: (1+1/H, ..., 1+1/H) where H = getRefH(M, N).
%
%   Configuration:
%     - Edit the 'algorithms' and 'problems' arrays below
%     - Adjust parameters (FE, N, runs) as needed
%     - Comment/uncomment tasks to run partial pipeline
%
%   All algorithms use wH variants (with heuristic initialization) to ensure
%   fair comparison via shared initial populations per (problem, run) pair.
%
%   Supports config-based algorithms ({@ConfigurableNSGA2CHVGSA, config})
%   created via generateCHVGSA() as well as wH baseline handles (@NSGAIIwH).

%% ========================================================================
%  CONFIGURATION
%  ========================================================================

%% Add PipelineFunctions to path
addpath(fullfile(fileparts(mfilename('fullpath')), 'PipelineFunctions'));

%% Define algorithms to benchmark
% C-HVGSA variants (via generateCHVGSA) — accepts HID automatically:
%   generateCHVGSA()                                     % Full C-HVGSA (default)
%   generateCHVGSA('use_normalization', false)            % Without normalization
%   generateCHVGSA('Qsize', 0)                            % Without archive (A0)
%   generateCHVGSA('eta_mode', 'constant_one')            % Constant step size = 1
%
% NSGA-II-HVGSA default display name: NSGA-II-HVGSA (mapped in getAlgorithmDisplayName)
%
% HVGSA on other baselines (single-class wrappers, accept HID automatically):
%   @ICMACHVGSA      — display name: ICMA-HVGSA
%   @CMOEACDCHVGSA   — display name: CMOEA-CD-HVGSA
% Both share the same default HVGSA configuration as generateCHVGSA(),
% but do not expose per-component ablation parameters.
%
% Baseline wH variants — accept shared initial population:
%   @NSGAIIwH, @CMOEACDwH, @ICMAwH, @SPEA2wH, @SMSEMOAwH
%
algorithms = { ...
    generateCHVGSA(), ...                   % NSGA-II-HVGSA (full, accepts HID)
    @ICMACHVGSA, ...                        % ICMA-HVGSA (accepts HID)
    @CMOEACDCHVGSA, ...                     % CMOEA-CD-HVGSA (accepts HID)
    @NSGAIIwH, ...                          % NSGA-II baseline (with shared init)
    @CMOEACDwH, ...                         % CMOEA-CD baseline (with shared init)
    @ICMAwH, ...                            % ICMA baseline (with shared init)
    @PPSwH, ...
    @ToPwH, ...
};

%% --- Main Benchmark: HVGSA algorithms vs other algorithms ---
% algorithms = { ...
%     % {@CMOEACDwH, 1, 1}, ...                          % CMOEA-CD baseline (with shared init)
%     % @ICMAwH, ...                             % ICMA baseline (with shared init)
%     % @NSGAIIwH, ...                           % NSGA-II baseline (with shared init)
%     % {@PPSwH, 0.9, 2}, ...                              % PPS baseline (with shared init)
%     % @CMOEADwH, ...                           % C-MOEA/D baseline (with shared init)
%     generateCHVGSA(), ...
% };


%% --- Ablation Group I: Effect of HVGSA Integration and Ablation Variants ---
% algorithms = { ...
%     generateCHVGSA(), ...                                   % NSGA-II-HVGSA (full, solution-wise norm)
%     generateCHVGSA('gradient_method', 'CGSA'), ...          % NSGA-II-HVGSA-FN (full normalization)
%     generateCHVGSA('use_expanded_front', false), ...         % NSGA-II-HVGSA-NE (without expanded front)
%     generateCHVGSA('use_interpolation', false), ...          % NSGA-II-HVGSA-NI (without interpolation)
%     @NSGAIIwH, ...                                          % NSGA-II (baseline)
% };

%% --- Ablation Group O: Testing normalization
% algorithms = { ... 
%     generateCHVGSA('use_normalization', 'obj'), ...          % NSGA-II-HVGSA-FN (full normalization)
%     generateCHVGSA('use_normalization', 'off'), ...          % NSGA-II-HVGSA-WN (without normalization)
%     generateCHVGSA('use_normalization', 'on'), ...         % NSGA-II-HVGSA-NE (without expanded front)
% };

%% --- Ablation Group X: Testing reference point
% algorithms = { ...
%     generateCHVGSA('use_normalization', 'on'), ...                                   % NSGA-II-HVGSA (full, solution-wise norm)
%     generateCHVGSA('refC', 1.05, 'use_normalization', 'on'), ...          % NSGA-II-HVGSA-FN (full normalization)
%     generateCHVGSA('refC', 1.1, 'use_normalization', 'on'), ...          % NSGA-II-HVGSA-WN (without normalization)
%     generateCHVGSA('refC', 1.2, 'use_normalization', 'on'), ...         % NSGA-II-HVGSA-NE (without expanded front)
%     generateCHVGSA('refC', 1.5, 'use_normalization', 'on'), ...         % NSGA-II-HVGSA-NE (without expanded front)
% };


%% --- Ablation Group II: Effect of Team Sizes U (Section IV-A) ---
% algorithms = { ...
%     generateCHVGSA(), ...                                   % NSGA-II-HVGSA (U = Rand([6,10]))
%     generateCHVGSA('U_mode', 'fixed', 'U_value', 2), ...   % NSGA-II-HVGSA-U2
%     generateCHVGSA('U_mode', 'fixed', 'U_value', 3), ...   % NSGA-II-HVGSA-U3
%     generateCHVGSA('U_mode', 'fixed', 'U_value', 4), ...   % NSGA-II-HVGSA-U4
%     generateCHVGSA('U_mode', 'fixed', 'U_value', 5), ...   % NSGA-II-HVGSA-U5
%     generateCHVGSA('U_mode', 'fixed', 'U_value', 6), ...   % NSGA-II-HVGSA-U6
%     generateCHVGSA('U_mode', 'fixed', 'U_value', 7), ...   % NSGA-II-HVGSA-U7
%     generateCHVGSA('U_mode', 'fixed', 'U_value', 8), ...   % NSGA-II-HVGSA-U8
%     generateCHVGSA('U_mode', 'fixed', 'U_value', 9), ...   % NSGA-II-HVGSA-U9
%     generateCHVGSA('U_mode', 'fixed', 'U_value', 10), ...  % NSGA-II-HVGSA-U10
% };

%% --- Ablation Group III: Effect of Search Radius Strategies and k_min (Section IV-B) ---
% algorithms = { ...
%     generateCHVGSA(), ...                                               % NSGA-II-HVGSA (mean, k_min=1)
%     generateCHVGSA('k_min', 2), ...                                    % NSGA-II-HVGSA-Me4
%     generateCHVGSA('k_min', 3), ...                                    % NSGA-II-HVGSA-Me7
%     generateCHVGSA('k_min', 4), ...                                   % NSGA-II-HVGSA-Me10
%     generateCHVGSA('sr_mode', 'min', 'k_min', 1), ...                  % NSGA-II-HVGSA-Mi1
%     generateCHVGSA('sr_mode', 'min', 'k_min', 2), ...                  % NSGA-II-HVGSA-Mi4
%     generateCHVGSA('sr_mode', 'min', 'k_min', 3), ...                  % NSGA-II-HVGSA-Mi7
%     generateCHVGSA('sr_mode', 'min', 'k_min', 4), ...                 % NSGA-II-HVGSA-Mi10
%     generateCHVGSA('sr_mode', 'max', 'k_min', 1), ...                  % NSGA-II-HVGSA-Ma1
%     generateCHVGSA('sr_mode', 'max', 'k_min', 2), ...                  % NSGA-II-HVGSA-Ma4
%     generateCHVGSA('sr_mode', 'max', 'k_min', 3), ...                  % NSGA-II-HVGSA-Ma7
%     generateCHVGSA('sr_mode', 'max', 'k_min', 4), ...                 % NSGA-II-HVGSA-Ma10
% };

%% --- Ablation Group IV: Effect of eta_0 for Interpolative Search (Section IV-D) ---
% algorithms = { ...
%     generateCHVGSA(), ...                                               % NSGA-II-HVGSA (adaptive: sqrt(n) -> 1/sqrt(n))
%     generateCHVGSA('eta_mode', 'constant_sqrtD'), ...                   % NSGA-II-HVGSA-S  (eta = sqrt(n))
%     generateCHVGSA('eta_mode', 'constant_one'), ...                     % NSGA-II-HVGSA-O  (eta = 1)
%     generateCHVGSA('eta_mode', 'constant_invSqrtD'), ...                % NSGA-II-HVGSA-IS (eta = 1/sqrt(n))
% };

%% Define problems to benchmark (RWMOP1-50)

problems = { ...
    @RWMOP1,  @RWMOP2,  @RWMOP3,  @RWMOP4,  @RWMOP5, ...
    @RWMOP6,  @RWMOP7,  @RWMOP8,  @RWMOP9,  @RWMOP10, ...
    @RWMOP11, @RWMOP12, @RWMOP13, @RWMOP14, @RWMOP15, ...
    @RWMOP16, @RWMOP17, @RWMOP18, @RWMOP19, @RWMOP20, ...
    @RWMOP21, @RWMOP22, @RWMOP23, @RWMOP24, @RWMOP25, ...
    @RWMOP26, @RWMOP27, @RWMOP28, @RWMOP29, @RWMOP30, ...
    @RWMOP31, @RWMOP32, @RWMOP33, @RWMOP34, @RWMOP35, ...
    @RWMOP36, @RWMOP37, @RWMOP38, @RWMOP39, @RWMOP40, ...
    @RWMOP41, @RWMOP42, @RWMOP43, @RWMOP44, @RWMOP45, ...
    @RWMOP46, @RWMOP47, @RWMOP48, @RWMOP49, @RWMOP50 ...
};
% problems = {@RWMOP2};

%% Benchmark parameters
params = struct(...
    'FE',   50000, ...   % Max function evaluations
    'runs', 31 ...        % Independent runs
);
% params = struct(...
%     'FE',   50000, ...   % Max function evaluations
%     'runs', 5 ...        % Independent runs
% );
% NOTE: params.N is set per-problem after parseProblemList (see below)

%% Direction flags (output PDFs — independent of each other)
runDirection1_WilcoxonTables    = true;  % Statistical tables with Wilcoxon test
runDirection2_PopulationFigures = false;  % Visualized median-run populations
runDirection3_ConvergencePlots  = false;  % Time-evolution convergence graphs
runDirection4_FriedmanNemenyi   = true; % Ranking tables + CD plots

%% Feasibility classification
% Feasible: RWMOP1-35, RWMOP50 (metric: normalized HV, speed: AUC of HV)
% Infeasible: RWMOP36-49 (metric: average CV, speed: -AUC of average CV)
infeasibleIndices = 36:49;

%% Parse problems into handles and names
[problemHandles, problemNames] = parseProblemList(problems);

%% Precompute per-problem population size based on objective dimensions
problemN = zeros(1, numel(problemHandles));
for i = 1:numel(problemHandles)
    pro = problemHandles{i}();
    problemN(i) = 100;
    fprintf('  %s: M=%d, N=%d\n', problemNames{i}, pro.M, problemN(i));
end
params.N = problemN;

%% Build feasibility mask (true = feasible, false = infeasible)
isFeasible = true(1, numel(problemHandles));
for i = 1:numel(problemNames)
    % Extract problem number from name (e.g., 'RWMOP36' -> 36)
    numStr = regexp(problemNames{i}, '\d+$', 'match');
    if ~isempty(numStr)
        probNum = str2double(numStr{1});
        if ismember(probNum, infeasibleIndices)
            isFeasible(i) = false;
        end
    end
end

fprintf('Pipeline configured: %d algorithms, %d problems (%d feasible, %d infeasible)\n', ...
    numel(algorithms), numel(problemHandles), sum(isFeasible), sum(~isFeasible));

%% ========================================================================
%%  TASK 0: CLEAN DATA (COMMENTED - USE WITH CAUTION)
%% ========================================================================
% disp("WARNING: WIPING DATA")
% pause(4)
% wipeDir('./Data')
% wipeDir('./TrimmedData')
% wipeDir('./IntermediateHV')
% wipeDir('./IntermediateAUC')
% wipeDir('./IntermediateCV')
% wipeDir('./Info/FinalHV')
% wipeDir('./Info/FinalCV')
% wipeDir('./Info/FinalAUC')
% wipeDir('./Info/FinalTime')
% wipeDir('./Info/MedianResults')
% wipeDir('./Info/ReferencePF')
% wipeDir('./Visualization/images')
% wipeDir('./AnytimeMetrics')
% return

%% ========================================================================
%%  TASK 1: RUN BENCHMARK EXPERIMENTS
%% ========================================================================
fprintf('\n=== Task 1: Running Benchmarks ===\n');
runBenchmarks(algorithms, problemHandles, params, problemNames);

%% If any files are unloadable after TASK 1, rerun using this:
rerunCorruptedExperiments(algorithms, params)


%% ========================================================================
%%  TASK 2: TRIM DATA
%% ========================================================================
fprintf('\n=== Task 2: Trimming Data ===\n');
trimBenchmarkData(algorithms, './Data', './TrimmedData');

%% ========================================================================
%% TASK 2.5: GENERATE REFERENCE PF & REFERENCE HV (Feasible Problems Only)
%% ========================================================================
fprintf('\n=== Task 2.5: Generating Reference PF & HV ===\n');
% generateReferencePF(problemHandles, problemNames, isFeasible, ...
%     struct('refFE', 500 * 120, 'refRuns', 5, 'targetN', 3000));
GenerateRefHVfromPF(problemHandles, problemNames, isFeasible, params.N);


%% ========================================================================
%% TASK 3: COMPUTE METRICS (HV, AUC, CV, -AUC)
%% ========================================================================
fprintf('\n=== Task 3: Computing Metrics ===\n');
computeAllMetrics(algorithms, problemHandles, params, problemNames, isFeasible);

%% ========================================================================
%% TASK 3.5: COMPUTE TIME METRICS
%% ========================================================================
fprintf('\n=== Task 3.5: Computing Time Metrics ===\n');
computeTimeMetrics(algorithms, problemHandles, params, problemNames);

%% ========================================================================
%%  TASK 4: SUMMARIZE METRICS
%% ========================================================================
fprintf('\n=== Task 4: Summarizing Metrics ===\n');
SummarizeMetrics(algorithms, problemNames, isFeasible, params.N);

%% ========================================================================
%%  TASK 7: EXTRACT MEDIAN RUNS
%% ========================================================================
fprintf('\n=== Task 7: Extracting Median Runs ===\n');
extractMedianRun(algorithms, problemNames, isFeasible);

%% ========================================================================
%%  DIRECTION 1: WILCOXON STATISTICAL TABLES PDF
%% ========================================================================
if runDirection1_WilcoxonTables
    fprintf('\n=== Direction 1: Generating Wilcoxon Tables ===\n');
    generateWilcoxonTables(algorithms, problemNames, isFeasible, params);
end

%% ========================================================================
%%  TASK 8: VISUALIZE RESULTS (prerequisite for Direction 2)
%% ========================================================================
if runDirection2_PopulationFigures
    fprintf('\n=== Task 8: Visualizing Results ===\n');
    visualizeResults(algorithms, problemHandles, problemNames, isFeasible);
end

%% ========================================================================
%%  DIRECTION 2: POPULATION FIGURES PDF
%% ========================================================================
if runDirection2_PopulationFigures
    fprintf('\n=== Direction 2: Generating Population Figures ===\n');
    generatePopulationFigures(algorithms, problemNames, isFeasible);
end

%% ========================================================================
%%  TASK 8.5: ANYTIME METRICS (prerequisite for Direction 3 + GUI)
%% ========================================================================
fprintf('\n=== Task 8.5: Computing Anytime Metrics ===\n');
ComputeAnytimeMetrics(algorithms, problemNames, isFeasible, params);
AnytimePerformanceGUI(algorithms, problemNames, isFeasible);

%% ========================================================================
%%  DIRECTION 3: CONVERGENCE PLOTS PDF
%% ========================================================================
if runDirection3_ConvergencePlots
    fprintf('\n=== Direction 3: Generating Convergence Plots ===\n');
    generateConvergencePlots(algorithms, problemNames, isFeasible, params);
end

%% ========================================================================
%%  DIRECTION 4: FRIEDMAN-NEMENYI RANKINGS & CD PLOTS PDF
%% ========================================================================
if runDirection4_FriedmanNemenyi
    fprintf('\n=== Direction 4: Friedman-Nemenyi Analysis ===\n');
    generateFriedmanNemenyiPDF(algorithms, problemNames, isFeasible, params);
end

%% ========================================================================
%%  TASK 9: GENERATE SUPPLEMENTARY MATERIALS
%% ========================================================================
fprintf('\n=== Task 9: Generating Supplementary Materials ===\n');
generateSupplementaryMaterials(algorithms, problemNames, isFeasible, params.N);

%% ========================================================================
%%  TASK 10: COMPILE LATEX
%% ========================================================================
fprintf('\n=== Task 10: Compiling LaTeX ===\n');
[status, cmdout] = system('pdflatex -interaction=nonstopmode SupplementaryMaterials.tex');
if status == 0
    fprintf('LaTeX compilation successful.\n');
else
    fprintf('LaTeX compilation failed:\n%s\n', cmdout);
end

fprintf('\n========================================\n');
fprintf('BENCHMARK PIPELINE COMPLETE\n');
fprintf('========================================\n');

%% ========================================================================
%%  HELPER FUNCTIONS
%% ========================================================================

function wipeDir(dirPath)
    if ~exist(dirPath, 'dir')
        fprintf('Directory does not exist: %s\n', dirPath);
        return;
    end

    % Delete subdirectories
    subdirs = dir(dirPath);
    subdirs = subdirs([subdirs.isdir]);
    subdirs = subdirs(~ismember({subdirs.name}, {'.', '..'}));
    for i = 1:length(subdirs)
        subdirPath = fullfile(dirPath, subdirs(i).name);
        fprintf('Deleting directory: %s\n', subdirPath);
        rmdir(subdirPath, 's');
    end

    % Delete .mat files
    matFiles = dir(fullfile(dirPath, '*.mat'));
    for i = 1:length(matFiles)
        filePath = fullfile(dirPath, matFiles(i).name);
        fprintf('Deleting file: %s\n', filePath);
        delete(filePath);
    end

    % Delete .png files
    pngFiles = dir(fullfile(dirPath, '*.png'));
    for i = 1:length(pngFiles)
        filePath = fullfile(dirPath, pngFiles(i).name);
        fprintf('Deleting file: %s\n', filePath);
        delete(filePath);
    end

    fprintf('Cleaned: %s\n\n', dirPath);
end
