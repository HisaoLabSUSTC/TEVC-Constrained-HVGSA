function ComputeAnytimeMetrics(algorithms, problemNames, isFeasible, params)
%COMPUTEANYTIMEMETRICS Compute per-generation metric trajectories for all pairs.
%
%   ComputeAnytimeMetrics(algorithms, problemNames, isFeasible, params)
%
%   For each (algorithm, problem, run), loads the raw data and computes
%   the metric at each generation snapshot:
%     - Feasible problems: normalized HV (using reference PF ideal/nadir)
%     - Infeasible problems: average constraint violation
%
%   Input:
%     algorithms   - Cell array of algorithm specs (handles or config cells)
%     problemNames - Cell array of problem name strings
%     isFeasible   - Logical vector (true = feasible, false = infeasible)
%     params       - Struct with fields: N, runs, dataDir (opt)
%
%   Output:
%     Saves to ./AnytimeMetrics/{alg}/AM_{filename}.mat containing:
%       feValues     - 1 x G vector of function evaluation counts
%       metricValues - 1 x G vector of metric at each snapshot
%       metricType   - 'HV' or 'CV'

    if nargin < 4, params = struct(); end
    N_vec   = getFieldDefault(params, 'N', 120);
    dataDir = getFieldDefault(params, 'dataDir', './Data');

    % Support both scalar N and per-problem N vector
    if isscalar(N_vec)
        N_vec = repmat(N_vec, 1, numel(problemNames));
    end

    fprintf('=== Computing Anytime Metrics ===\n');

    algorithmNames = cellfun(@(a) getAlgorithmName(a), algorithms, 'UniformOutput', false);
    numAlgorithms = numel(algorithmNames);
    numProblems   = numel(problemNames);

    %% Build flat pair lists for parfor
    numPairs = numAlgorithms * numProblems;
    pairAlgIdx  = zeros(1, numPairs);
    pairProbIdx = zeros(1, numPairs);
    pairN       = zeros(1, numPairs);
    idx = 1;
    for i = 1:numAlgorithms
        for k = 1:numProblems
            pairAlgIdx(idx)  = i;
            pairProbIdx(idx) = k;
            pairN(idx)       = N_vec(k);
            idx = idx + 1;
        end
    end

    %% Progress tracking
    progressQueue = parallel.pool.DataQueue;
    startTime = tic;
    afterEach(progressQueue, @(data) progressCallback(data, numPairs, startTime));

    fprintf('Computing anytime metrics for %d (algorithm, problem) pairs...\n', numPairs);

    %% Parallel computation over all pairs
    parfor pi = 1:numPairs
        ai = pairAlgIdx(pi);
        ki = pairProbIdx(pi);
        algName  = algorithmNames{ai};
        probName = problemNames{ki};
        feasible = isFeasible(ki);
        N_i      = pairN(pi);

        processAnytimePair(algName, probName, feasible, dataDir, N_i);

        send(progressQueue, struct('alg', algName, 'prob', probName));
    end

    fprintf('\nAnytime metrics complete! Elapsed: %.1fs\n', toc(startTime));
    fprintf('=== Anytime metric computation completed ===\n');
end

%% ==================== Core Processing ====================

function processAnytimePair(algName, probName, feasible, dataDir, N)
%PROCESSANYTIMEPAIR Compute anytime metrics for one (alg, prob) pair.
%   Processes all run files found in the Data directory.

    algDir = fullfile(dataDir, algName);
    if ~exist(algDir, 'dir')
        return;
    end

    % Find matching files
    matFiles = dir(fullfile(algDir, '*.mat'));
    pattern = sprintf('^%s_%s(_M\\d+_D\\d+)?_\\d+$', ...
        regexptranslate('escape', algName), ...
        regexptranslate('escape', probName));

    matchingFiles = {};
    for j = 1:length(matFiles)
        [~, fname, ~] = fileparts(matFiles(j).name);
        if ~isempty(regexp(fname, pattern, 'once'))
            matchingFiles{end+1} = matFiles(j).name; %#ok<AGROW>
        end
    end

    if isempty(matchingFiles)
        return;
    end

    % Preload reference data for feasible problems
    if feasible
        try
            [~, ideal, nadir] = loadReferencePF(probName);
            M = numel(ideal);
            H = getRefH(M, N);
            % ref = ones(1, M) * (1 + 1/H);
            ref = ones(1, M) * 1.2;
        catch
            return;
        end
    end

    % Output directory
    outDir = fullfile('./AnytimeMetrics', algName);
    ensureDir(outDir);

    % Process each run file
    for j = 1:numel(matchingFiles)
        filename = matchingFiles{j};
        [~, baseName, ~] = fileparts(filename);

        try
            rawData = load(fullfile(algDir, filename), 'result');
            result = rawData.result;
        catch
            continue;
        end

        nGens = size(result, 1);
        feValues     = zeros(1, nGens);
        metricValues = zeros(1, nGens);

        for g = 1:nGens
            feValues(g) = result{g, 1};
            pop = result{g, 2};

            if feasible
                gObj = pop.objs;
                gCon = pop.cons;
                gFeasObj = filterFeasible(gObj, gCon);
                metricValues(g) = computeNormalizedHV(gFeasObj, ideal, nadir, ref);
            else
                % Empty snapshot (e.g., PPS's final empty feasible
                % archive) would give a trivial CV of 0; carry forward
                % the previous generation's value so the trajectory
                % reflects the working search population rather than
                % PPS's archive swap on the final iteration.
                if isempty(pop) || isempty(pop.cons)
                    if g > 1
                        metricValues(g) = metricValues(g-1);
                    else
                        metricValues(g) = NaN;
                    end
                else
                    gCon = pop.cons;
                    metricValues(g) = computeAverageCV(gCon);
                end
            end
        end

        if feasible
            metricType = 'HV'; %#ok<NASGU>
        else
            metricType = 'CV'; %#ok<NASGU>
        end

        outFile = fullfile(outDir, sprintf('AM_%s.mat', baseName));
        save(outFile, 'feValues', 'metricValues', 'metricType');
    end
end

%% ==================== Local Helpers ====================

function feasObj = filterFeasible(popObj, popCon)
    if isempty(popCon)
        feasObj = popObj;
        return;
    end
    totalCV = sum(max(0, popCon), 2);
    feasMask = totalCV <= 0;
    feasObj = popObj(feasMask, :);
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

function progressCallback(data, total, startTime)
    persistent completed;
    if isempty(completed)
        completed = 0;
    end
    completed = completed + 1;
    elapsed = toc(startTime);
    avgTime = elapsed / completed;
    remaining = (total - completed) * avgTime;
    fprintf('  [%d/%d] %s - %s | ETA: %.0fs\n', ...
        completed, total, data.alg, data.prob, remaining);
end
