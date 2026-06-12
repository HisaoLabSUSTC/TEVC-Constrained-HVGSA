function computeTimeMetrics(algorithms, problemHandles, params, problemNames)
%COMPUTETIMEMETRICS Extract runtime metrics from raw benchmark data.
%
%   computeTimeMetrics(algorithms, problemHandles, params, problemNames)
%
%   Reads metric.runtime from ./Data/ files (not TrimmedData) and saves
%   per-algorithm time maps in ./Info/FinalTime/.
%
%   Input:
%     algorithms     - Cell array of algorithm specs
%     problemHandles - Cell array of problem function handles
%     params         - Struct with fields: runs, dataDir (opt)
%     problemNames   - Cell array of problem name strings

    if nargin < 3, params = struct(); end
    runs    = getFieldDefault(params, 'runs', 31);
    dataDir = getFieldDefault(params, 'dataDir', './Data');

    fprintf('=== Computing Time Metrics ===\n');

    % Get names
    algorithmNames = cellfun(@(a) getAlgorithmName(a), algorithms, 'UniformOutput', false);
    if nargin < 4 || isempty(problemNames)
        problemNames = cellfun(@func2str, problemHandles, 'UniformOutput', false);
    end

    numAlgorithms = numel(algorithmNames);
    numProblems   = numel(problemNames);
    numPairs      = numAlgorithms * numProblems;

    % Build flat pair lists for parfor
    pairAlgorithms = cell(1, numPairs);
    pairProblems   = cell(1, numPairs);
    idx = 1;
    for i = 1:numAlgorithms
        for k = 1:numProblems
            pairAlgorithms{idx} = algorithmNames{i};
            pairProblems{idx}   = problemNames{k};
            idx = idx + 1;
        end
    end

    %% Setup intermediate directory
    intermediateTimeDir = './IntermediateTime';
    ensureDir(intermediateTimeDir);

    %% Progress tracking
    progressQueue = parallel.pool.DataQueue;
    startTime = tic;
    afterEach(progressQueue, @(data) progressCallback(data, numPairs, startTime));

    fprintf('Phase 1: Extracting runtimes for %d (algorithm, problem) pairs...\n', numPairs);

    %% Phase 1: Parallel time extraction
    parfor i = 1:numPairs
        alg  = pairAlgorithms{i};
        prob = pairProblems{i};

        [timeValues, numRuns] = processTimeMetric(alg, prob, dataDir, runs);

        outFile = fullfile(intermediateTimeDir, sprintf('%s_%s.mat', alg, prob));
        saveIntermediateMetric(outFile, timeValues, 'timeValues');

        send(progressQueue, struct('alg', alg, 'prob', prob, 'runs', numRuns));
    end

    fprintf('\nPhase 1 complete! Elapsed: %.1fs\n', toc(startTime));

    %% Phase 2: Collect intermediate results
    fprintf('Phase 2: Collecting results into final structure...\n');

    for i = 1:numAlgorithms
        alg = algorithmNames{i};
        prob2time = containers.Map();

        for k = 1:numProblems
            prob = problemNames{k};
            intermediateFile = fullfile(intermediateTimeDir, sprintf('%s_%s.mat', alg, prob));
            if exist(intermediateFile, 'file')
                data = load(intermediateFile);
                prob2time(prob) = data.timeValues;
            end
        end

        targetDir = sprintf('./Info/FinalTime/%s', alg);
        ensureDir(targetDir);
        save(fullfile(targetDir, 'prob2time.mat'), 'prob2time');
        fprintf('  Saved Time: %s\n', targetDir);
    end

    fprintf('\nAll done! Total time: %.1fs\n', toc(startTime));
    fprintf('=== Time metric extraction completed ===\n');
end

%% ==================== Local Functions ====================

function [timeValues, numRuns] = processTimeMetric(algorithmName, problemName, dataDir, runs)
%PROCESSTIMEMETRIC Extract runtime for one (algorithm, problem) pair.
%   Scans ./Data/{algName}/ for files matching the PlatEMO naming convention:
%   {AlgName}_{ProbName}_M{M}_D{D}_{Run}.mat

    subdirPath = fullfile(dataDir, algorithmName);
    if ~exist(subdirPath, 'dir')
        numRuns = 0;
        timeValues = zeros(1, 0);
        return;
    end

    matFiles = dir(fullfile(subdirPath, '*.mat'));

    % Match: {AlgName}_{ProbName}_M{M}_D{D}_{Run}.mat
    % Also supports: {AlgName}_{ProbName}_{Run}.mat
    pattern = sprintf('^%s_%s(_M\\d+_D\\d+)?_\\d+$', ...
        regexptranslate('escape', algorithmName), ...
        regexptranslate('escape', problemName));

    matchingFiles = {};
    for j = 1:length(matFiles)
        [~, fname, ~] = fileparts(matFiles(j).name);
        if ~isempty(regexp(fname, pattern, 'once'))
            matchingFiles{end+1} = matFiles(j).name; %#ok<AGROW>
        end
    end

    numRuns = numel(matchingFiles);
    timeValues = zeros(1, numRuns);

    for j = 1:numRuns
        try
            data = load(fullfile(subdirPath, matchingFiles{j}), 'metric');
            if isfield(data, 'metric') && isfield(data.metric, 'runtime')
                timeValues(j) = data.metric.runtime;
            else
                timeValues(j) = NaN;
            end
        catch
            timeValues(j) = NaN;
        end
    end
end

function val = getFieldDefault(s, field, default)
    if isfield(s, field)
        val = s.(field);
    else
        val = default;
    end
end

function ensureDir(dirPath)
    if ~exist(dirPath, 'dir')
        mkdir(dirPath);
    end
end

function saveIntermediateMetric(filepath, values, varName)
    S = struct();
    S.(varName) = values;
    save(filepath, '-struct', 'S');
end

function progressCallback(data, total, startTime)
    persistent completed;
    if isempty(completed)
        completed = 0;
    end
    completed = completed + 1;
    elapsed = toc(startTime);
    avgTime = elapsed / completed;
    remaining = (total - completed) * avgTime;
    fprintf('  [%d/%d] %s - %s (%d runs) | ETA: %.0fs\n', ...
        completed, total, data.alg, data.prob, data.runs, remaining);
end
