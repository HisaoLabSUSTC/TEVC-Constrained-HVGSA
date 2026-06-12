function computeAllMetrics(algorithms, problemHandles, params, problemNames, isFeasible)
%COMPUTEALLMETRICS Compute HV, AUC, CV, and -AUC metrics for all pairs.
%
%   computeAllMetrics(algorithms, problemHandles, params, problemNames, isFeasible)
%
%   Two-phase execution:
%     Phase 1: Parallel metric computation via parfor over (algorithm, problem) pairs.
%     Phase 2: Sequential collection into final per-algorithm structures.
%
%   Feasible problems (RWMOP1-35, RWMOP50):
%     - Primary metric: normalized HV in [0,1] space (higher is better)
%     - Speed metric: AUC of per-generation normalized HV (higher is better)
%
%   Infeasible problems (RWMOP36-49):
%     - Primary metric: average constraint violation (lower is better)
%     - Speed metric: -AUC of per-generation average CV (lower is better)
%
%   Input:
%     algorithms     - Cell array of algorithm specs
%     problemHandles - Cell array of problem function handles
%     params         - Struct with fields: N, runs, trimmedDir (opt), dataDir (opt)
%     problemNames   - Cell array of problem name strings
%     isFeasible     - Logical vector (true = feasible, false = infeasible)
%
%   Output:
%     Saves intermediate results to ./IntermediateHV/, ./IntermediateCV/, ./IntermediateAUC/
%     Saves final results to:
%       ./Info/FinalHV/{alg}/prob2hv.mat   (feasible problems)
%       ./Info/FinalCV/{alg}/prob2cv.mat   (infeasible problems)
%       ./Info/FinalAUC/{alg}/prob2auc.mat (all problems)

    if nargin < 3, params = struct(); end
    N_vec      = getFieldDefault(params, 'N', 120);
    runs       = getFieldDefault(params, 'runs', 31);
    trimmedDir = getFieldDefault(params, 'trimmedDir', './TrimmedData');
    dataDir    = getFieldDefault(params, 'dataDir', './Data');

    % Support both scalar N and per-problem N vector
    if isscalar(N_vec)
        N_vec = repmat(N_vec, 1, numel(problemNames));
    end

    fprintf('=== Computing Metrics (HV, AUC, CV, -AUC) ===\n');
    fprintf('  Feasible problems:   normalized HV + AUC of HV\n');
    fprintf('  Infeasible problems: average CV + -AUC of CV\n');

    % Get algorithm names
    algorithmNames = cellfun(@(a) getAlgorithmName(a), algorithms, 'UniformOutput', false);

    numAlgorithms = numel(algorithmNames);
    numProblems   = numel(problemNames);
    numPairs      = numAlgorithms * numProblems;

    % Build flat pair lists for parfor (avoid cell-of-cells indexing)
    pairAlgorithms = cell(1, numPairs);
    pairProblems   = cell(1, numPairs);
    pairFeasible   = false(1, numPairs);
    pairN          = zeros(1, numPairs);
    idx = 1;
    for i = 1:numAlgorithms
        for k = 1:numProblems
            pairAlgorithms{idx} = algorithmNames{i};
            pairProblems{idx}   = problemNames{k};
            pairFeasible(idx)   = isFeasible(k);
            pairN(idx)          = N_vec(k);
            idx = idx + 1;
        end
    end

    %% Setup intermediate directories
    intermediateHVDir  = './IntermediateHV';
    intermediateCVDir  = './IntermediateCV';
    intermediateAUCDir = './IntermediateAUC';
    ensureDir(intermediateHVDir);
    ensureDir(intermediateCVDir);
    ensureDir(intermediateAUCDir);

    %% Progress tracking
    progressQueue = parallel.pool.DataQueue;
    startTime = tic;
    afterEach(progressQueue, @(data) progressCallback(data, numPairs, startTime));

    fprintf('Phase 1: Computing metrics for %d (algorithm, problem) pairs...\n', numPairs);

    %% Phase 1: Parallel metric computation
    parfor i = 1:numPairs
        alg  = pairAlgorithms{i};
        prob = pairProblems{i};
        feas = pairFeasible(i);
        N_i  = pairN(i);

        [metricValues, aucValues, numRuns] = ...
            processAlgorithmProblem(alg, prob, feas, trimmedDir, dataDir, N_i, runs);

        % Save intermediate primary metric
        if feas
            outFile = fullfile(intermediateHVDir, sprintf('%s_%s.mat', alg, prob));
            saveIntermediateMetric(outFile, metricValues, 'hvValues');
        else
            outFile = fullfile(intermediateCVDir, sprintf('%s_%s.mat', alg, prob));
            saveIntermediateMetric(outFile, metricValues, 'cvValues');
        end

        % Save intermediate AUC (both feasible and infeasible)
        outAUCFile = fullfile(intermediateAUCDir, sprintf('%s_%s.mat', alg, prob));
        saveIntermediateMetric(outAUCFile, aucValues, 'aucValues');

        send(progressQueue, struct('alg', alg, 'prob', prob, 'runs', numRuns, 'feasible', feas));
    end

    fprintf('\nPhase 1 complete! Elapsed: %.1fs\n', toc(startTime));

    %% Phase 2: Collect intermediate results into final structure
    fprintf('Phase 2: Collecting results into final structure...\n');

    for i = 1:numAlgorithms
        alg = algorithmNames{i};
        prob2hv  = containers.Map();
        prob2cv  = containers.Map();
        prob2auc = containers.Map();

        for k = 1:numProblems
            prob = problemNames{k};

            if isFeasible(k)
                % Load HV
                hvFile = fullfile(intermediateHVDir, sprintf('%s_%s.mat', alg, prob));
                if exist(hvFile, 'file')
                    data = load(hvFile);
                    prob2hv(prob) = data.hvValues;
                end
            else
                % Load CV
                cvFile = fullfile(intermediateCVDir, sprintf('%s_%s.mat', alg, prob));
                if exist(cvFile, 'file')
                    data = load(cvFile);
                    prob2cv(prob) = data.cvValues;
                end
            end

            % Load AUC
            aucFile = fullfile(intermediateAUCDir, sprintf('%s_%s.mat', alg, prob));
            if exist(aucFile, 'file')
                data = load(aucFile);
                prob2auc(prob) = data.aucValues;
            end
        end

        % Save final HV results (feasible problems)
        if prob2hv.Count > 0
            targetDir = sprintf('./Info/FinalHV/%s', alg);
            ensureDir(targetDir);
            save(fullfile(targetDir, 'prob2hv.mat'), 'prob2hv');
            fprintf('  Saved HV (%d problems): %s\n', prob2hv.Count, targetDir);
        end

        % Save final CV results (infeasible problems)
        if prob2cv.Count > 0
            targetDir = sprintf('./Info/FinalCV/%s', alg);
            ensureDir(targetDir);
            save(fullfile(targetDir, 'prob2cv.mat'), 'prob2cv');
            fprintf('  Saved CV (%d problems): %s\n', prob2cv.Count, targetDir);
        end

        % Save final AUC results (all problems)
        if prob2auc.Count > 0
            targetDir = sprintf('./Info/FinalAUC/%s', alg);
            ensureDir(targetDir);
            save(fullfile(targetDir, 'prob2auc.mat'), 'prob2auc');
            fprintf('  Saved AUC (%d problems): %s\n', prob2auc.Count, targetDir);
        end
    end

    fprintf('\nAll done! Total time: %.1fs\n', toc(startTime));
    fprintf('=== Metric computation completed ===\n');
end

%% ==================== Helper Functions ====================

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
    if data.feasible
        metricType = 'HV+AUC';
    else
        metricType = 'CV-AUC';
    end
    fprintf('  [%d/%d] %s - %s (%d runs, %s) | ETA: %.0fs\n', ...
        completed, total, data.alg, data.prob, data.runs, metricType, remaining);
end
