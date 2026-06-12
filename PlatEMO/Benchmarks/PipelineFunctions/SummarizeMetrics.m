function SummarizeMetrics(algorithms, problemNames, isFeasible, N)
%SUMMARIZEMETRICS Aggregate metrics into summary tables with mean +/- std.
%
%   SummarizeMetrics(algorithms, problemNames, isFeasible, N)
%
%   Generates five summary tables:
%     1. Feasible HV (higher is better)
%     2. Feasible AUC of normalized HV (higher is better)
%     3. Infeasible average CV (lower is better)
%     4. Infeasible -AUC of average CV (lower is better)
%     5. Runtime (lower is better)
%
%   Each table: rows = problems, columns = algorithms, cells = mean +/- std.
%   Best mean per problem is marked with (*) in console output.
%
%   Input:
%     algorithms   - Cell array of algorithm specs (handles or config cells)
%     problemNames - Cell array of problem name strings
%     isFeasible   - Logical vector (true = feasible, false = infeasible)
%     N            - Population size (unused, reserved for future use)
%
%   Output:
%     Saves:
%       ./Info/FinalHV/hvSummary.mat
%       ./Info/FinalAUC/aucFeasibleSummary.mat
%       ./Info/FinalCV/cvSummary.mat
%       ./Info/FinalAUC/aucInfeasibleSummary.mat
%       ./Info/FinalTime/timeSummary.mat

    %% Extract algorithm names
    algorithmNames = cellfun(@(a) getAlgorithmName(a), algorithms, 'UniformOutput', false);

    % Split problems by feasibility
    feasibleProblems   = problemNames(isFeasible);
    infeasibleProblems = problemNames(~isFeasible);

    fprintf('\n========== Summarizing Metrics ==========\n');
    fprintf('  %d algorithms, %d feasible problems, %d infeasible problems\n', ...
        numel(algorithmNames), numel(feasibleProblems), numel(infeasibleProblems));

    %% Phase 1: HV Summary (feasible problems, higher is better)
    if ~isempty(feasibleProblems)
        fprintf('\n---------- Phase 1: Normalized HV Summary ----------\n');
        hvSummary = buildAndPrintSummary(algorithmNames, feasibleProblems, ...
            './Info/FinalHV', 'prob2hv', 'Normalized HV', '%.4f', true);
        saveSummary('./Info/FinalHV', 'hvSummary.mat', 'hvSummary', hvSummary);
    end

    %% Phase 2: AUC of HV Summary (feasible problems, higher is better)
    if ~isempty(feasibleProblems)
        fprintf('\n---------- Phase 2: AUC of Normalized HV Summary ----------\n');
        aucFeasibleSummary = buildAndPrintSummary(algorithmNames, feasibleProblems, ...
            './Info/FinalAUC', 'prob2auc', 'AUC of HV', '%.4f', true);
        saveSummary('./Info/FinalAUC', 'aucFeasibleSummary.mat', 'aucFeasibleSummary', aucFeasibleSummary);
    end

    %% Phase 3: CV Summary (infeasible problems, lower is better)
    if ~isempty(infeasibleProblems)
        fprintf('\n---------- Phase 3: Average CV Summary ----------\n');
        cvSummary = buildAndPrintSummary(algorithmNames, infeasibleProblems, ...
            './Info/FinalCV', 'prob2cv', 'Average CV', '%.4e', false);
        saveSummary('./Info/FinalCV', 'cvSummary.mat', 'cvSummary', cvSummary);
    end

    %% Phase 4: -AUC of CV Summary (infeasible problems, lower is better)
    if ~isempty(infeasibleProblems)
        fprintf('\n---------- Phase 4: -AUC of Average CV Summary ----------\n');
        aucInfeasibleSummary = buildAndPrintSummary(algorithmNames, infeasibleProblems, ...
            './Info/FinalAUC', 'prob2auc', '-AUC of CV', '%.4e', false);
        saveSummary('./Info/FinalAUC', 'aucInfeasibleSummary.mat', 'aucInfeasibleSummary', aucInfeasibleSummary);
    end

    %% Phase 5: Time Summary (all problems, lower is better)
    fprintf('\n---------- Phase 5: Runtime Summary ----------\n');
    timeSummary = buildAndPrintSummary(algorithmNames, problemNames, ...
        './Info/FinalTime', 'prob2time', 'Runtime (s)', '%.2f', false);
    saveSummary('./Info/FinalTime', 'timeSummary.mat', 'timeSummary', timeSummary);

    fprintf('\n========== Summary Complete ==========\n');
end

%% ==================== Core Logic ====================

function summary = buildAndPrintSummary(algorithmNames, problemSubset, ...
    baseDir, mapVarName, metricLabel, numFmt, higherIsBetter)
%BUILDANDPRINTSUMMARY Build summary struct and print formatted table.
%
%   For each (problem, algorithm) pair:
%     - Loads the containers.Map from baseDir/{alg}/{mapVarName}.mat
%     - Computes mean and std over runs
%     - Identifies best (max or min) mean per problem
%     - Stores results in a struct and prints a formatted console table

    numAlgorithms = numel(algorithmNames);
    numProblems   = numel(problemSubset);
    summary       = struct();

    % Collect means for best-detection
    meanMatrix = NaN(numProblems, numAlgorithms);

    for i = 1:numProblems
        probName = problemSubset{i};
        probResult = struct();

        for j = 1:numAlgorithms
            alg = algorithmNames{j};
            algField = matlab.lang.makeValidName(alg);

            values = loadMetricValues(baseDir, alg, mapVarName, probName);

            if isempty(values) || all(isnan(values))
                probResult.(algField) = 'N/A';
                probResult.([algField '_mean']) = NaN;
                probResult.([algField '_std']) = NaN;
                probResult.([algField '_raw']) = [];
            else
                m = mean(values, 'omitnan');
                s = std(values, 0, 'omitnan');
                fmtStr = [numFmt ' +/- ' numFmt];
                probResult.(algField) = sprintf(fmtStr, m, s);
                probResult.([algField '_mean']) = m;
                probResult.([algField '_std']) = s;
                probResult.([algField '_raw']) = values;
                meanMatrix(i, j) = m;
            end
        end

        summary.(matlab.lang.makeValidName(probName)) = probResult;
    end

    % Print formatted table with best marked
    printTable(metricLabel, summary, algorithmNames, problemSubset, ...
        meanMatrix, higherIsBetter, numFmt);
end

%% ==================== Table Printing ====================

function printTable(metricLabel, summary, algorithmNames, problemSubset, ...
    meanMatrix, higherIsBetter, numFmt)
%PRINTTABLE Print a formatted console table with best values marked (*).

    numAlgorithms = numel(algorithmNames);
    colWidth = max(20, max(cellfun(@length, algorithmNames)) + 4);

    % Header
    fprintf('\n  %s (Mean +/- Std)\n\n', metricLabel);
    headerFmt = sprintf('  %%-16s');
    for j = 1:numAlgorithms
        headerFmt = [headerFmt sprintf(' | %%-%ds', colWidth)]; %#ok<AGROW>
    end
    fprintf([headerFmt '\n'], 'Problem', algorithmNames{:});
    fprintf('  %s\n', repmat('-', 1, 18 + (colWidth + 3) * numAlgorithms));

    % Rows
    probFields = fieldnames(summary);
    for i = 1:length(probFields)
        prob = probFields{i};
        result = summary.(prob);

        % Find best algorithm for this problem
        rowMeans = meanMatrix(i, :);
        if all(isnan(rowMeans))
            bestIdx = [];
        elseif higherIsBetter
            [~, bestIdx] = max(rowMeans);
        else
            [~, bestIdx] = min(rowMeans);
        end

        % Build row
        rowFmt = '  %-16s';
        rowArgs = {prob};
        for j = 1:numAlgorithms
            algField = matlab.lang.makeValidName(algorithmNames{j});
            cellStr = result.(algField);
            if ~isempty(bestIdx) && j == bestIdx && ~strcmp(cellStr, 'N/A')
                cellStr = ['(*) ' cellStr]; %#ok<AGROW>
            end
            rowFmt = [rowFmt sprintf(' | %%-%ds', colWidth)]; %#ok<AGROW>
            rowArgs{end+1} = cellStr; %#ok<AGROW>
        end
        fprintf([rowFmt '\n'], rowArgs{:});
    end
    fprintf('\n');
end

%% ==================== Data Loading ====================

function values = loadMetricValues(baseDir, algorithmName, mapVarName, problemName)
%LOADMETRICVALUES Load metric values for one (algorithm, problem) pair.
%   Returns the run-values vector, or empty if not found.

    algPath = fullfile(baseDir, algorithmName, [mapVarName '.mat']);

    if ~exist(algPath, 'file')
        values = [];
        return;
    end

    data = load(algPath);
    if ~isfield(data, mapVarName)
        % Try loading first variable if name doesn't match
        fn = fieldnames(data);
        if ~isempty(fn)
            map = data.(fn{1});
        else
            values = [];
            return;
        end
    else
        map = data.(mapVarName);
    end

    if isa(map, 'containers.Map') && isKey(map, problemName)
        values = map(problemName);
    else
        values = [];
    end
end

%% ==================== Save Helper ====================

function saveSummary(dirPath, fileName, varName, varValue)
%SAVESUMMARY Save a summary struct to a .mat file.
    if ~exist(dirPath, 'dir')
        mkdir(dirPath);
    end
    S = struct();
    S.(varName) = varValue;
    outPath = fullfile(dirPath, fileName);
    save(outPath, '-struct', 'S');
    fprintf('  Saved %s to: %s\n', varName, outPath);
end
