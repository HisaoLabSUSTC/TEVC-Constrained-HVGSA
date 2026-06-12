function rerunCorruptedExperiments(algorithms, params, logPath, deleteCorrupted)
%RERUNCORRUPTEDEXPERIMENTS Re-run experiments that failed during trimming
%
%   rerunCorruptedExperiments(algorithms, params)
%   rerunCorruptedExperiments(algorithms, params, logPath, deleteCorrupted)
%
%   Input:
%     algorithms      - Cell array of algorithm specs (same as runBenchmarks)
%     params          - Struct with fields: FE, N, runs
%     logPath         - Path to error log (default: './Info/Logs/corrupted_files.mat')
%     deleteCorrupted - Delete corrupted files before re-running (default: true)
%
%   Reads the error log from trimBenchmarkData, deletes corrupted files,
%   and calls runBenchmarks to regenerate them.

    if nargin < 3
        logPath = './Info/Logs/corrupted_files.mat';
    end
    if nargin < 4
        deleteCorrupted = true;
    end

    fprintf('=== Re-running Corrupted Experiments ===\n');

    %% Load error log
    if ~exist(logPath, 'file')
        fprintf('No error log found at: %s\nNothing to re-run.\n', logPath);
        return;
    end

    data = load(logPath, 'errorLog');
    errorLog = data.errorLog;

    if isempty(errorLog)
        fprintf('Error log is empty. Nothing to re-run.\n');
        return;
    end

    fprintf('Found %d corrupted files in log\n', numel(errorLog));

    %% Build algorithm name to spec mapping
    algNameToSpec = containers.Map();
    for i = 1:numel(algorithms)
        algName = getAlgorithmName(algorithms{i});
        algNameToSpec(algName) = algorithms{i};
    end

    %% Group by algorithm and problem
    algProblemRuns = containers.Map();
    for i = 1:numel(errorLog)
        entry = errorLog(i);
        algName = entry.algName;
        problemName = entry.problemName;

        if ~isKey(algProblemRuns, algName)
            algProblemRuns(algName) = containers.Map();
        end

        probMap = algProblemRuns(algName);
        if ~isKey(probMap, problemName)
            probMap(problemName) = [];
        end
        probMap(problemName) = [probMap(problemName), entry.runNumber];
        algProblemRuns(algName) = probMap;
    end

    %% Delete corrupted files
    if deleteCorrupted
        fprintf('\nDeleting corrupted files...\n');
        deletedCount = 0;
        for i = 1:numel(errorLog)
            filePath = errorLog(i).filePath;
            if exist(filePath, 'file')
                try
                    delete(filePath);
                    fprintf('  Deleted: %s\n', filePath);
                    deletedCount = deletedCount + 1;
                catch ME
                    fprintf('  [ERROR] Could not delete %s: %s\n', filePath, ME.message);
                end
            end
        end
        fprintf('Deleted %d corrupted files\n', deletedCount);
    end

    %% Re-run experiments
    algNames = keys(algProblemRuns);
    fprintf('\nRe-running experiments for %d algorithm(s)...\n', numel(algNames));

    totalRerun = 0;

    for a = 1:numel(algNames)
        algName = algNames{a};

        if ~isKey(algNameToSpec, algName)
            fprintf('\n[WARNING] Algorithm "%s" not found. Skipping.\n', algName);
            continue;
        end

        algSpec = algNameToSpec(algName);
        probMap = algProblemRuns(algName);
        probNames = keys(probMap);

        fprintf('\n--- Algorithm: %s (%d problems) ---\n', algName, numel(probNames));

        problemHandles = {};
        rerunProbNames = {};
        for p = 1:numel(probNames)
            problemName = probNames{p};
            runNumbers = probMap(problemName);
            fprintf('  Problem: %s (runs: %s)\n', problemName, mat2str(runNumbers));

            try
                problemHandle = str2func(problemName);
                problemHandles{end+1} = problemHandle; %#ok<AGROW>
                rerunProbNames{end+1} = problemName; %#ok<AGROW>
                totalRerun = totalRerun + numel(runNumbers);
            catch
                fprintf('    [WARNING] Could not create handle for: %s\n', problemName);
            end
        end

        if isempty(problemHandles)
            fprintf('  No valid problems to re-run.\n');
            continue;
        end

        % Compute per-problem N for this subset
        rerunN = zeros(1, numel(problemHandles));
        for pp = 1:numel(problemHandles)
            pro = problemHandles{pp}();
            rerunN(pp) = getPopulationSize(pro.M);
        end
        rerunParams = params;
        rerunParams.N = rerunN;

        fprintf('  Running benchmarks...\n');
        try
            runBenchmarks({algSpec}, problemHandles, rerunParams, rerunProbNames);
        catch ME
            fprintf('  [ERROR] runBenchmarks failed: %s\n', ME.message);
        end
    end

    fprintf('\n=== Re-run Summary ===\n');
    fprintf('Total experiments to re-run: %d\n', totalRerun);

    %% Prompt to clear log
    clearLog = input('Clear error log? (y/n): ', 's');
    if strcmpi(clearLog, 'y')
        if exist(logPath, 'file')
            delete(logPath);
            fprintf('Error log cleared.\n');
        end
    else
        fprintf('Error log kept at: %s\n', logPath);
    end

    fprintf('=== Re-run completed ===\n');
    fprintf('Run trimBenchmarkData again to process the regenerated files.\n');
end
