function runBenchmarks(algorithms, problemHandles, params, problemNames, useParallel)
%RUNBENCHMARKS Execute benchmark experiments for all algorithm-problem combinations
%
%   runBenchmarks(algorithms, problemHandles, params, problemNames)
%   runBenchmarks(algorithms, problemHandles, params, problemNames, useParallel)
%
%   Input:
%     algorithms     - Cell array of algorithm specs (handles or config cells)
%     problemHandles - Cell array of problem function handles (e.g. {@RWMOP1, ...})
%     params         - Struct with fields:
%                        FE   - Max function evaluations (default: 100000)
%                        N    - Population size (default: 120)
%                        runs - Number of independent runs (default: 31)
%     problemNames   - Cell array of problem name strings
%     useParallel    - Use parfor (default: true)
%
%   Results are saved to ./Data/{algName}/{algName}_{probName}_{run}.mat
%   Existing files are skipped (supports resumption).
%
%   All algorithms that support heuristic initialization (wH suffix or
%   ConfigurableNSGA2CHVGSA) are seeded with a shared initial population
%   per (problem, run) pair to ensure fair comparison.

    if nargin < 5
        useParallel = true;
    end

    FE   = getFieldDefault(params, 'FE', 100000);
    N_vec = getFieldDefault(params, 'N', 120);
    runs = getFieldDefault(params, 'runs', 31);

    % Support both scalar N (backward compat) and per-problem N vector
    if isscalar(N_vec)
        N_vec = repmat(N_vec, 1, numel(problemHandles));
    end

    fprintf('=== Running Benchmarks ===\n');
    fprintf('Algorithms: %d, Problems: %d, Runs: %d\n', ...
        numel(algorithms), numel(problemHandles), runs);

    %% Generate shared initial populations
    initPopDir = './Info/InitialPopulation';
    generateInitialPopulations(problemHandles, N_vec, runs, initPopDir, problemNames);

    %% Create all combinations
    [P, A, R] = ndgrid(1:numel(problemHandles), 1:numel(algorithms), 1:runs);
    combinations = [P(:), A(:), R(:)];
    total_tasks = size(combinations, 1);
    fprintf('Starting %d tasks...\n', total_tasks);

    %% Precompute per-problem save intervals
    save_intervals = ceil(FE ./ N_vec);

    %% Run experiments
    if useParallel
        parfor idx = 1:total_tasks
            prob_idx = combinations(idx, 1);
            runOneTask(idx, combinations, algorithms, problemHandles, ...
                problemNames, N_vec(prob_idx), FE, save_intervals(prob_idx), initPopDir);
        end
    else
        for idx = 1:total_tasks
            prob_idx = combinations(idx, 1);
            runOneTask(idx, combinations, algorithms, problemHandles, ...
                problemNames, N_vec(prob_idx), FE, save_intervals(prob_idx), initPopDir);
        end
    end

    fprintf('=== Benchmark completed ===\n');
end

%% ==================== Local Functions ====================

function runOneTask(idx, combinations, algorithms, problemHandles, ...
        problemNames, N, FE, save_interval, initPopDir)

    prob_idx = combinations(idx, 1);
    algo_idx = combinations(idx, 2);
    run_num  = combinations(idx, 3);

    algorithmSpec  = algorithms{algo_idx};
    problemHandle  = problemHandles{prob_idx};
    prob_name      = problemNames{prob_idx};
    algo_name      = getAlgorithmName(algorithmSpec);

    % Build file paths
    % PlatEMO/Algorithms/ALGORITHM.m saves results as:
    %   PlatEMO/Data/{algName}/{algName}_{problemClass}_M{M}_D{D}_{run}.mat
    % Anchor to PlatEMO root (platemo.m cd's there) and match M/D via glob
    % so we don't need to instantiate the problem here.
    platemo_root = fileparts(which('platemo'));
    prev_folder  = fullfile(platemo_root, 'Data', algo_name);
    prev_pattern = sprintf('%s_%s_M*_D*_%d.mat', algo_name, prob_name, run_num);

    % Skip if already evaluated
    if ~isempty(dir(fullfile(prev_folder, prev_pattern)))
        fprintf('Skipping (exists): %s with %s (Run %d)\n', ...
            prob_name, algo_name, run_num);
        return
    end

    % Build HID path for this (problem, run) pair
    heuristicPath = fullfile(initPopDir, sprintf('HS-%s_%d.mat', prob_name, run_num));

    % Prepare algorithm with HID
    algorithm_with_param = prepareAlgorithmForPlatemo(algorithmSpec, heuristicPath);

    % Run platemo
    platemo('problem', problemHandle, 'N', N, ...
        'save', save_interval, 'maxFE', FE, ...
        'algorithm', algorithm_with_param, 'run', run_num);

    fprintf('Completed: %s with %s (Run %d)\n', prob_name, algo_name, run_num);
end

function val = getFieldDefault(s, field, default)
    if isfield(s, field)
        val = s.(field);
    else
        val = default;
    end
end
