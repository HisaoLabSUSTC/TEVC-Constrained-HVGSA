function generateWilcoxonTables(algorithms, problemNames, isFeasible, params) %#ok<INUSD>
%GENERATEWILCOXONTABLES Generate Wilcoxon rank-sum statistical tables PDF.
%
%   generateWilcoxonTables(algorithms, problemNames, isFeasible, params)
%
%   Generates a LaTeX document (IEEEtran journal format) with up to 5 table*
%   environments, each containing mean +/- std values with Wilcoxon rank-sum
%   test indicators (+), (-), (=) comparing each algorithm to the reference
%   algorithm (last in the list).
%
%   Tables generated:
%     1. Feasible: Normalized HV        (higher is better)
%     2. Feasible: AUC of Normalized HV  (higher is better)
%     3. Infeasible: Average CV          (lower is better)
%     4. Infeasible: -AUC of Average CV  (lower is better)
%     5. All: Runtime in seconds         (lower is better)
%
%   Input:
%     algorithms   - Cell array of algorithm specs
%     problemNames - Cell array of problem name strings
%     isFeasible   - Logical vector (true = feasible)
%     params       - Struct with fields: FE, N, runs (reserved)
%
%   Output:
%     Writes ./WilcoxonTables.tex and compiles to ./WilcoxonTables.pdf

    fprintf('=== Generating Wilcoxon Statistical Tables ===\n');

    algorithmNames = cellfun(@(a) getAlgorithmName(a), algorithms, ...
        'UniformOutput', false);
    displayNames = cellfun(@(n) getAlgorithmDisplayName(n), algorithmNames, ...
        'UniformOutput', false);
    numAlg = numel(algorithmNames);

    if numAlg < 2
        warning('generateWilcoxonTables:TooFewAlgorithms', ...
            'Need at least 2 algorithms for Wilcoxon test.');
        return;
    end

    % The first algorithm in the config is the reference. Rotate it to the
    % last column so it appears in the rightmost position, matching the
    % existing "reference is last column" convention used below.
    permIdx        = [2:numAlg, 1];
    algorithmNames = algorithmNames(permIdx);
    displayNames   = displayNames(permIdx);

    feasibleProblems   = problemNames(isFeasible);
    infeasibleProblems = problemNames(~isFeasible);
    refAlgIdx = numAlg;  % After the rotation, the reference is the last column

    %% Open output file
    texPath = './WilcoxonTables.tex';
    fid = fopen(texPath, 'w');
    if fid == -1
        error('Could not open %s for writing.', texPath);
    end
    cleanupObj = onCleanup(@() fclose(fid));

    %% Write preamble (IEEEtran journal format)
    writePreamble(fid);

    %% Table 1: Feasible — Normalized HV (higher is better)
    if ~isempty(feasibleProblems)
        fprintf('  Writing Table 1: Feasible HV...\n');
        writeWilcoxonTable(fid, algorithmNames, displayNames, feasibleProblems, ...
            './Info/FinalHV', 'prob2hv', ...
            'Normalized Hypervolume (Mean $\pm$ Std)', ...
            'tab:wilcoxon-hv', '%.4f', ' \pm ', true, refAlgIdx);
    end

    %% Table 2: Feasible — AUC of Normalized HV (higher is better)
    if ~isempty(feasibleProblems)
        fprintf('  Writing Table 2: Feasible AUC-HV...\n');
        writeWilcoxonTable(fid, algorithmNames, displayNames, feasibleProblems, ...
            './Info/FinalAUC', 'prob2auc', ...
            'AUC of Normalized Hypervolume (Mean $\pm$ Std)', ...
            'tab:wilcoxon-auc-hv', '%.4f', ' \pm ', true, refAlgIdx);
    end

    %% Table 3: Infeasible — Average CV (lower is better)
    if ~isempty(infeasibleProblems)
        fprintf('  Writing Table 3: Infeasible CV...\n');
        writeWilcoxonTable(fid, algorithmNames, displayNames, infeasibleProblems, ...
            './Info/FinalCV', 'prob2cv', ...
            'Average Constraint Violation (Mean $\!\pm\!$ Std)', ...
            'tab:wilcoxon-cv', '%.3f', '\!\pm\!', false, refAlgIdx);
    end

    %% Table 4: Infeasible — -AUC of Average CV (lower is better)
    if ~isempty(infeasibleProblems)
        fprintf('  Writing Table 4: Infeasible -AUC-CV...\n');
        writeWilcoxonTable(fid, algorithmNames, displayNames, infeasibleProblems, ...
            './Info/FinalAUC', 'prob2auc', ...
            '$-$AUC of Average Constraint Violation (Mean $\!\pm\!$ Std)', ...
            'tab:wilcoxon-auc-cv', '%.3f', '\!\pm\!', true, refAlgIdx);
    end

    %% Table 5: Runtime — all problems (lower is better)
    fprintf('  Writing Table 5: Runtime...\n');
    writeWilcoxonTable(fid, algorithmNames, displayNames, problemNames, ...
        './Info/FinalTime', 'prob2time', ...
        'Runtime in Seconds (Mean $\pm$ Std)', ...
        'tab:wilcoxon-time', '%.2f', ' \pm ', false, refAlgIdx);

    %% Write postamble
    fprintf(fid, '\n\\end{document}\n');

    fprintf('  Written to: %s\n', texPath);

    %% Compile LaTeX
    fprintf('  Compiling LaTeX...\n');
    [status, cmdout] = system('pdflatex -interaction=nonstopmode WilcoxonTables.tex');
    if status == 0
        fprintf('  Compilation successful: WilcoxonTables.pdf\n');
    else
        fprintf('  LaTeX compilation failed:\n%s\n', cmdout);
    end

    fprintf('=== Wilcoxon tables generation complete ===\n');
end

%% ==================== Preamble ====================

function writePreamble(fid)
    fprintf(fid, '\\documentclass[journal]{IEEEtran}\n');
    fprintf(fid, '\\usepackage{booktabs}\n');
    fprintf(fid, '\\usepackage{amsmath}\n');
    fprintf(fid, '\\usepackage{array}\n');
    fprintf(fid, '\\usepackage[table]{xcolor}\n');
    fprintf(fid, '\\usepackage{caption}\n');
    fprintf(fid, '\\usepackage{graphicx}\n');
    fprintf(fid, '\n');
    fprintf(fid, '\\begin{document}\n\n');
end

%% ==================== Wilcoxon Table ====================

function writeWilcoxonTable(fid, algorithmNames, displayNames, problemSubset, ...
    baseDir, mapVarName, caption, label, numFmt, pmLatex, ...
    higherIsBetter, refAlgIdx)
%WRITEWILCOXONTABLE Write one table* with Wilcoxon rank-sum test markers.

    numAlg  = numel(algorithmNames);
    numProb = numel(problemSubset);
    alpha   = 0.05;

    %% Load raw per-run values
    rawData    = cell(numProb, numAlg);
    meanMatrix = NaN(numProb, numAlg);
    stdMatrix  = NaN(numProb, numAlg);

    for i = 1:numProb
        for j = 1:numAlg
            values = loadMetricValues(baseDir, algorithmNames{j}, ...
                mapVarName, problemSubset{i});
            rawData{i,j} = values;
            if ~isempty(values) && ~all(isnan(values))
                meanMatrix(i,j) = mean(values, 'omitnan');
                stdMatrix(i,j)  = std(values, 0, 'omitnan');
            end
        end
    end

    %% Wilcoxon rank-sum test: compare each algorithm to reference
    markers = cell(numProb, numAlg);
    for i = 1:numProb
        for j = 1:numAlg
            if j == refAlgIdx
                markers{i,j} = '';  % No marker for reference algorithm
                continue;
            end

            algVals = rawData{i,j};
            refVals = rawData{i,refAlgIdx};

            % Filter out NaNs
            if ~isempty(algVals), algVals = algVals(~isnan(algVals)); end
            if ~isempty(refVals), refVals = refVals(~isnan(refVals)); end

            if isempty(algVals) || isempty(refVals)
                markers{i,j} = '';
                continue;
            end

            % Wilcoxon rank-sum test (two-sided)
            try
                p = ranksum(algVals(:), refVals(:));
            catch
                markers{i,j} = '$(=)$';
                continue;
            end

            if p < alpha
                % Significant difference — determine direction
                algMean = meanMatrix(i,j);
                refMean = meanMatrix(i,refAlgIdx);
                if higherIsBetter
                    if algMean > refMean
                        markers{i,j} = '$(+)$';
                    else
                        markers{i,j} = '$(-)$';
                    end
                else
                    if algMean < refMean
                        markers{i,j} = '$(+)$';
                    else
                        markers{i,j} = '$(-)$';
                    end
                end
            else
                markers{i,j} = '$(=)$';
            end
        end
    end

    %% Count wins / losses / ties per algorithm
    wins   = zeros(1, numAlg);
    losses = zeros(1, numAlg);
    ties   = zeros(1, numAlg);
    for j = 1:numAlg
        if j == refAlgIdx, continue; end
        for i = 1:numProb
            switch markers{i,j}
                case '$(+)$', wins(j)   = wins(j) + 1;
                case '$(-)$', losses(j) = losses(j) + 1;
                case '$(=)$', ties(j)   = ties(j) + 1;
            end
        end
    end

    %% Identify best mean per row (NaN-aware)
    bestIdx = zeros(numProb, 1);
    for i = 1:numProb
        row = meanMatrix(i,:);
        if all(isnan(row))
            bestIdx(i) = 0;
        elseif higherIsBetter
            [~, bestIdx(i)] = max(row, [], 'omitnan');
        else
            [~, bestIdx(i)] = min(row, [], 'omitnan');
        end
    end

    %% Write table* environment
    fprintf(fid, '\\begin{table*}[!t]\n');
    fprintf(fid, '\\centering\n');
    fprintf(fid, '\\caption{%s}\n', caption);
    fprintf(fid, '\\label{%s}\n', label);

    colSpec = ['l' repmat('c', 1, numAlg)];
    fprintf(fid, '\\begin{tabular}{%s}\n', colSpec);
    fprintf(fid, '\\toprule\n');

    % Header row
    fprintf(fid, 'Problem');
    for j = 1:numAlg
        fprintf(fid, ' & %s', escapeLatex(displayNames{j}));
    end
    fprintf(fid, ' \\\\\n');
    fprintf(fid, '\\midrule\n');

    % Data rows
    for i = 1:numProb
        fprintf(fid, '%s', escapeLatex(getProblemDisplayName(problemSubset{i})));
        for j = 1:numAlg
            if isnan(meanMatrix(i,j))
                cellStr = 'N/A';
            else
                mStr = formatCompact(meanMatrix(i,j), numFmt);
                sStr = formatCompact(stdMatrix(i,j), numFmt);
                cellStr = ['$' mStr pmLatex sStr '$'];
            end

            % Bold the best mean
            if bestIdx(i) == j && ~isnan(meanMatrix(i,j))
                cellStr = ['\textbf{' cellStr '}'];
            end

            % Append Wilcoxon marker
            if ~isempty(markers{i,j})
                cellStr = [cellStr ' ' markers{i,j}];
            end

            fprintf(fid, ' & %s', cellStr);
        end
        fprintf(fid, ' \\\\\n');
    end

    % Summary row: $(+,-,=)$ & $(w,l,t)$ & ... & $--$
    fprintf(fid, '\\midrule\n');
    fprintf(fid, '\\hspace{0.3em}$(+,-,=)$');
    for j = 1:numAlg
        if j == refAlgIdx
            fprintf(fid, ' & $--$');
        else
            fprintf(fid, ' & $(%d, %d, %d)$', wins(j), losses(j), ties(j));
        end
    end
    fprintf(fid, ' \\\\\n');

    fprintf(fid, '\\bottomrule\n');
    fprintf(fid, '\\end{tabular}\n');

    % Footnote explaining markers
    if higherIsBetter
        dirStr = 'higher is better';
    else
        dirStr = 'lower is better';
    end
    fprintf(fid, '\\vspace{0.5em}\n');
    fprintf(fid, ['\\parbox{0.95\\textwidth}{\\footnotesize ' ...
        '$(+)$, $(-)$, and $(=)$ indicate that the result is ' ...
        'significantly better than, worse than, or comparable to ' ...
        '%s (Wilcoxon rank-sum test, $\\alpha=0.05$; %s).}\n'], ...
        escapeLatex(displayNames{refAlgIdx}), dirStr);

    fprintf(fid, '\\end{table*}\n\n');
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

%% ==================== LaTeX Utilities ====================

function escaped = escapeLatex(str)
%ESCAPELATEX Escape special LaTeX characters in a string.
    escaped = strrep(str, '_', '\_');
    escaped = strrep(escaped, '&', '\&');
    escaped = strrep(escaped, '%', '\%');
    escaped = strrep(escaped, '#', '\#');
end

function str = formatCompact(val, numFmt)
%FORMATCOMPACT Format number, switching to compact scientific for extreme magnitudes.
%   Values with |val| >= 1000 or |val| < 0.001 use compact notation (e.g. 5.47e5).
    if val == 0 || isnan(val) || isinf(val)
        str = sprintf(numFmt, val);
        return;
    end
    if abs(val) >= 1000 || abs(val) < 0.001
        e = floor(log10(abs(val)));
        m = val / 10^e;
        str = sprintf('%.2fe%d', m, e);
    else
        str = sprintf(numFmt, val);
    end
end
