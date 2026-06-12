function exportCSVforCritDD(algorithms, problemNames, isFeasible, params) %#ok<INUSD>
%EXPORTCSVFORCRITDD Export metric data as CSVs for critdd CD diagrams.
%
%   exportCSVforCritDD(algorithms, problemNames, isFeasible, params)
%
%   Exports up to 4 CSV files into ./CDPlots/ for the critdd Python library:
%     cd_hv.csv      — Normalized HV for feasible problems (maximize)
%     cd_auc_hv.csv  — AUC of Normalized HV for feasible problems (maximize)
%     cd_cv.csv      — Average CV for infeasible problems (minimize)
%     cd_auc_cv.csv  — -AUC of Average CV for infeasible problems (maximize after negation)
%
%   CSV schema: classifier_name,dataset_name,metric
%     where dataset_name = {probName}_R{run}
%
%   Input:
%     algorithms   - Cell array of algorithm specs
%     problemNames - Cell array of problem name strings
%     isFeasible   - Logical vector (true = feasible)
%     params       - Struct with fields: FE, N, runs (reserved)
%
%   Output:
%     Writes CSV files to ./CDPlots/

    fprintf('  Exporting CSVs for Critical Difference diagrams...\n');

    algorithmNames = cellfun(@(a) getAlgorithmName(a), algorithms, ...
        'UniformOutput', false);

    %% Create output directory
    outDir = './CDPlots';
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    feasibleProblems   = problemNames(isFeasible);
    infeasibleProblems = problemNames(~isFeasible);

    %% Export feasible metrics
    if ~isempty(feasibleProblems)
        exportOneCSV(algorithmNames, feasibleProblems, ...
            './Info/FinalHV', 'prob2hv', ...
            fullfile(outDir, 'cd_hv.csv'));

        exportOneCSV(algorithmNames, feasibleProblems, ...
            './Info/FinalAUC', 'prob2auc', ...
            fullfile(outDir, 'cd_auc_hv.csv'));
    end

    %% Export infeasible metrics
    %
    % For infeasible problems, a NaN per-run value (e.g., PPS producing an
    % empty feasible archive, which would otherwise report a misleading
    % CV of 0) must be ranked as worst — not silently dropped by critdd.
    % We substitute each NaN with a per-dataset sentinel strictly worse
    % than every non-NaN value in the same (problem, run) dataset.
    if ~isempty(infeasibleProblems)
        % cd_cv.csv — lower is better (higher = worse)
        exportOneCSV(algorithmNames, infeasibleProblems, ...
            './Info/FinalCV', 'prob2cv', ...
            fullfile(outDir, 'cd_cv.csv'), ...
            'nanReplaceDirection', 'higherIsWorse');

        % cd_auc_cv.csv — higher is better (lower = worse)
        exportOneCSV(algorithmNames, infeasibleProblems, ...
            './Info/FinalAUC', 'prob2auc', ...
            fullfile(outDir, 'cd_auc_cv.csv'), ...
            'nanReplaceDirection', 'lowerIsWorse');
    end

    %% Export runtime metric (all problems, lower is better)
    exportOneCSV(algorithmNames, problemNames, ...
        './Info/FinalTime', 'prob2time', ...
        fullfile(outDir, 'cd_time.csv'));

    fprintf('  CSV export complete.\n');
end

%% ==================== Core Export ====================

function exportOneCSV(algorithmNames, problemSubset, baseDir, mapVarName, outCSV, varargin)
%EXPORTONECSV Write one CSV file with per-run metric values.
%
%   Reports a summary of how many algorithms contributed data, since the
%   downstream Python CD-plot step silently skips metrics whose CSV has
%   fewer than two classifiers.
%
%   Optional name/value:
%     'nanReplaceDirection' - 'none' (default), 'higherIsWorse', or
%                             'lowerIsWorse'. When set, any NaN per-run
%                             value is replaced with a sentinel strictly
%                             worse than every non-NaN value observed in
%                             the same (problem, run) dataset, so the
%                             algorithm is ranked worst rather than
%                             dropped by critdd.

    p = inputParser;
    addParameter(p, 'nanReplaceDirection', 'none', ...
        @(s) any(strcmp(s, {'none', 'higherIsWorse', 'lowerIsWorse'})));
    parse(p, varargin{:});
    nanDir = p.Results.nanReplaceDirection;

    numAlg  = numel(algorithmNames);
    numProb = numel(problemSubset);

    %% Pass 1 — load per-run values into memory so we can compute
    %           per-dataset sentinels when NaN replacement is requested.
    % valueMatrix{p, a} = 1xR vector of per-run metric values (may contain
    % NaN). Missing entries are represented by an empty vector.
    valueMatrix = cell(numProb, numAlg);
    maxRunsByProb = zeros(1, numProb);
    for a = 1:numAlg
        for pi = 1:numProb
            values = loadMetricValues(baseDir, algorithmNames{a}, ...
                mapVarName, problemSubset{pi});
            valueMatrix{pi, a} = values;
            if ~isempty(values)
                maxRunsByProb(pi) = max(maxRunsByProb(pi), numel(values));
            end
        end
    end

    %% Compute per-dataset (problem, run) worst-plus-one sentinels
    % datasetSentinel{pi} is a 1xR vector; NaN where no non-NaN values
    % exist for any algorithm on that dataset (then there is nothing to
    % rank against, and those NaN cells are simply skipped).
    datasetSentinel = cell(1, numProb);
    if ~strcmp(nanDir, 'none')
        for pi = 1:numProb
            R = maxRunsByProb(pi);
            sentinels = NaN(1, R);
            for r = 1:R
                vals = zeros(0, 1);
                for a = 1:numAlg
                    v = valueMatrix{pi, a};
                    if numel(v) >= r && ~isnan(v(r))
                        vals(end+1, 1) = v(r); %#ok<AGROW>
                    end
                end
                if isempty(vals)
                    continue;
                end
                switch nanDir
                    case 'higherIsWorse'   % e.g., CV — minimize
                        worst = max(vals);
                        sentinels(r) = worst + max(1, abs(worst));
                    case 'lowerIsWorse'    % e.g., -AUC of CV — maximize
                        worst = min(vals);
                        sentinels(r) = worst - max(1, abs(worst));
                end
            end
            datasetSentinel{pi} = sentinels;
        end
    end

    %% Pass 2 — write the CSV, substituting NaN with the sentinel when asked.
    fid = fopen(outCSV, 'w');
    if fid == -1
        error('Could not open output CSV: %s', outCSV);
    end
    cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, 'classifier_name,dataset_name,metric\n');

    numRows        = 0;
    numSentinels   = 0;
    algsWithData   = {};
    algsNoData     = {};

    for a = 1:numAlg
        alg         = algorithmNames{a};
        algRowCount = 0;

        for pi = 1:numProb
            prob   = problemSubset{pi};
            values = valueMatrix{pi, a};

            if isempty(values) || all(isnan(values))
                % If the algorithm has no entries at all for this problem,
                % there is nothing to rank even with sentinel substitution.
                % Skip.
                if ~strcmp(nanDir, 'none') && ~isempty(datasetSentinel{pi})
                    % Emit sentinel rows for runs where the algorithm is
                    % missing/NaN but other algorithms produced values.
                    sentinels = datasetSentinel{pi};
                    R = maxRunsByProb(pi);
                    for r = 1:R
                        if ~isnan(sentinels(r))
                            if numel(values) >= r && ~isnan(values(r))
                                continue; %#ok<ALIGN>
                            end
                            fprintf(fid, '%s,%s_R%d,%.15g\n', ...
                                alg, prob, r, sentinels(r));
                            algRowCount  = algRowCount + 1;
                            numSentinels = numSentinels + 1;
                        end
                    end
                end
                continue;
            end

            R = numel(values);
            for r = 1:R
                if ~isnan(values(r))
                    fprintf(fid, '%s,%s_R%d,%.15g\n', alg, prob, r, values(r));
                    algRowCount = algRowCount + 1;
                elseif ~strcmp(nanDir, 'none')
                    sentinels = datasetSentinel{pi};
                    if r <= numel(sentinels) && ~isnan(sentinels(r))
                        fprintf(fid, '%s,%s_R%d,%.15g\n', ...
                            alg, prob, r, sentinels(r));
                        algRowCount  = algRowCount + 1;
                        numSentinels = numSentinels + 1;
                    end
                end
            end
        end

        if algRowCount > 0
            algsWithData{end+1} = alg; %#ok<AGROW>
            numRows = numRows + algRowCount;
        else
            algsNoData{end+1} = alg; %#ok<AGROW>
        end
    end

    if numSentinels > 0
        fprintf('    Written: %s  (%d rows, %d/%d algorithms have data, %d worst-rank sentinels)\n', ...
            outCSV, numRows, numel(algsWithData), numel(algorithmNames), numSentinels);
    else
        fprintf('    Written: %s  (%d rows, %d/%d algorithms have data)\n', ...
            outCSV, numRows, numel(algsWithData), numel(algorithmNames));
    end

    if ~isempty(algsNoData)
        fprintf('      Missing %s data for: %s\n', ...
            mapVarName, strjoin(algsNoData, ', '));
    end

    if numel(algsWithData) < 2
        warning('exportCSVforCritDD:InsufficientAlgorithms', ...
            ['%s: only %d algorithm(s) have data; CD plot requires >= 2. ', ...
             'Run computeAllMetrics/computeTimeMetrics for the missing ', ...
             'algorithms.'], outCSV, numel(algsWithData));
    end
end

%% ==================== Data Loading ====================

function values = loadMetricValues(baseDir, algorithmName, mapVarName, problemName)
%LOADMETRICVALUES Load raw per-run metric values for one (algorithm, problem) pair.
    values = [];

    algPath = fullfile(baseDir, algorithmName, [mapVarName '.mat']);
    if ~exist(algPath, 'file')
        return;
    end

    data = load(algPath);
    if isfield(data, mapVarName)
        map = data.(mapVarName);
    else
        fn = fieldnames(data);
        if ~isempty(fn)
            map = data.(fn{1});
        else
            return;
        end
    end

    if isa(map, 'containers.Map') && isKey(map, problemName)
        values = map(problemName);
    end
end
