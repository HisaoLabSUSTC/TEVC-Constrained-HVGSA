function generateSupplementaryMaterials(algorithms, problemNames, isFeasible, N)
%GENERATESUPPLEMENTARYMATERIALS Auto-generate LaTeX document with metric tables.
%
%   generateSupplementaryMaterials(algorithms, problemNames, isFeasible, N)
%
%   Generates a self-contained LaTeX document with five tables:
%     Table 1: Feasible problems — Normalized HV (mean +/- std)
%     Table 2: Feasible problems — AUC of normalized HV
%     Table 3: Infeasible problems — Average CV (mean +/- std)
%     Table 4: Infeasible problems — -AUC of average CV
%     Table 5: Runtime (mean +/- std) across all problems
%
%   Best values per problem are typeset in bold.
%
%   Input:
%     algorithms   - Cell array of algorithm specs
%     problemNames - Cell array of problem name strings
%     isFeasible   - Logical vector (true = feasible, false = infeasible)
%     N            - Population size (unused, reserved)
%
%   Output:
%     Writes ./SupplementaryMaterials.tex

    fprintf('=== Generating Supplementary Materials ===\n');

    algorithmNames = cellfun(@(a) getAlgorithmName(a), algorithms, 'UniformOutput', false);
    numAlgorithms = numel(algorithmNames);

    feasibleProblems   = problemNames(isFeasible);
    infeasibleProblems = problemNames(~isFeasible);

    %% Open output file
    texPath = './SupplementaryMaterials.tex';
    fid = fopen(texPath, 'w');
    if fid == -1
        error('Could not open %s for writing.', texPath);
    end

    cleanupObj = onCleanup(@() fclose(fid));

    %% Write preamble
    writePreamble(fid, algorithmNames);

    %% Table 1: Feasible HV
    if ~isempty(feasibleProblems)
        fprintf('  Writing Table 1: Feasible HV...\n');
        writeMetricTable(fid, algorithmNames, feasibleProblems, ...
            './Info/FinalHV', 'prob2hv', ...
            'Normalized Hypervolume (Mean $\pm$ Std)', ...
            'tab:hv', '%.4f', true);
    end

    %% Table 2: Feasible AUC of HV
    if ~isempty(feasibleProblems)
        fprintf('  Writing Table 2: Feasible AUC of HV...\n');
        writeMetricTable(fid, algorithmNames, feasibleProblems, ...
            './Info/FinalAUC', 'prob2auc', ...
            'AUC of Normalized Hypervolume (Mean $\pm$ Std)', ...
            'tab:auc-hv', '%.4f', true);
    end

    %% Table 3: Infeasible CV
    if ~isempty(infeasibleProblems)
        fprintf('  Writing Table 3: Infeasible CV...\n');
        writeMetricTable(fid, algorithmNames, infeasibleProblems, ...
            './Info/FinalCV', 'prob2cv', ...
            'Average Constraint Violation (Mean $\pm$ Std)', ...
            'tab:cv', '%.4e', false);
    end

    %% Table 4: Infeasible -AUC of CV
    if ~isempty(infeasibleProblems)
        fprintf('  Writing Table 4: Infeasible -AUC of CV...\n');
        writeMetricTable(fid, algorithmNames, infeasibleProblems, ...
            './Info/FinalAUC', 'prob2auc', ...
            '$-$AUC of Average Constraint Violation (Mean $\pm$ Std)', ...
            'tab:auc-cv', '%.4e', false);
    end

    %% Table 5: Runtime
    fprintf('  Writing Table 5: Runtime...\n');
    writeMetricTable(fid, algorithmNames, problemNames, ...
        './Info/FinalTime', 'prob2time', ...
        'Runtime in Seconds (Mean $\pm$ Std)', ...
        'tab:time', '%.2f', false);

    %% Write postamble
    writePostamble(fid);

    fprintf('  Written to: %s\n', texPath);
    fprintf('=== Supplementary materials generation complete ===\n');
end

%% ==================== Preamble / Postamble ====================

function writePreamble(fid, algorithmNames)
    fprintf(fid, '\\documentclass[a4paper,10pt]{article}\n');
    fprintf(fid, '\\usepackage[margin=1cm,landscape]{geometry}\n');
    fprintf(fid, '\\usepackage{booktabs}\n');
    fprintf(fid, '\\usepackage{longtable}\n');
    fprintf(fid, '\\usepackage{amsmath}\n');
    fprintf(fid, '\\usepackage{array}\n');
    fprintf(fid, '\\usepackage[table]{xcolor}\n');
    fprintf(fid, '\\usepackage{caption}\n');
    fprintf(fid, '\n');
    % Adaptive font size based on algorithm count
    numAlg = numel(algorithmNames);
    if numAlg > 6
        fprintf(fid, '\\usepackage[fontsize=7pt]{fontsize}\n');
    elseif numAlg > 4
        fprintf(fid, '\\usepackage[fontsize=8pt]{fontsize}\n');
    end
    fprintf(fid, '\n');
    fprintf(fid, '\\begin{document}\n');
    fprintf(fid, '\\pagestyle{empty}\n');
    fprintf(fid, '\n');
    fprintf(fid, '\\begin{center}\n');
    fprintf(fid, '{\\Large\\bfseries Supplementary Materials: Benchmark Results}\n');
    fprintf(fid, '\\end{center}\n');
    fprintf(fid, '\\vspace{1em}\n\n');
end

function writePostamble(fid)
    fprintf(fid, '\n\\end{document}\n');
end

%% ==================== Table Generation ====================

function writeMetricTable(fid, algorithmNames, problemSubset, ...
    baseDir, mapVarName, caption, label, numFmt, higherIsBetter)
%WRITEMETRICTABLE Write a single longtable to the LaTeX file.

    numAlgorithms = numel(algorithmNames);
    numProblems   = numel(problemSubset);

    % Collect data: means and formatted strings
    meanMatrix = NaN(numProblems, numAlgorithms);
    cellStrs   = cell(numProblems, numAlgorithms);

    for i = 1:numProblems
        probName = problemSubset{i};
        for j = 1:numAlgorithms
            algName = algorithmNames{j};
            values = loadMetricValues(baseDir, algName, mapVarName, probName);

            if isempty(values) || all(isnan(values))
                cellStrs{i,j} = 'N/A';
            else
                m = mean(values, 'omitnan');
                s = std(values, 0, 'omitnan');
                meanMatrix(i,j) = m;
                mStr = formatCompact(m, numFmt);
                sStr = formatCompact(s, numFmt);
                cellStrs{i,j} = ['$' mStr ' \pm ' sStr '$'];
            end
        end
    end

    % Identify best per row
    bestIdx = zeros(numProblems, 1);
    for i = 1:numProblems
        row = meanMatrix(i, :);
        if all(isnan(row))
            bestIdx(i) = 0;
        elseif higherIsBetter
            [~, bestIdx(i)] = max(row);
        else
            [~, bestIdx(i)] = min(row);
        end
    end

    %% Write longtable
    % Column spec: l for problem + c for each algorithm
    colSpec = ['l' repmat('c', 1, numAlgorithms)];
    fprintf(fid, '\\begin{longtable}{%s}\n', colSpec);
    fprintf(fid, '\\caption{%s}\\label{%s}\\\\\n', caption, label);
    fprintf(fid, '\\toprule\n');

    % Header row with escaped algorithm names
    fprintf(fid, 'Problem');
    for j = 1:numAlgorithms
        fprintf(fid, ' & %s', escapeLatex(algorithmNames{j}));
    end
    fprintf(fid, ' \\\\\n');
    fprintf(fid, '\\midrule\n');
    fprintf(fid, '\\endfirsthead\n\n');

    % Continuation header
    fprintf(fid, '\\multicolumn{%d}{c}{\\tablename\\ \\thetable{} -- continued}\\\\\n', ...
        numAlgorithms + 1);
    fprintf(fid, '\\toprule\n');
    fprintf(fid, 'Problem');
    for j = 1:numAlgorithms
        fprintf(fid, ' & %s', escapeLatex(algorithmNames{j}));
    end
    fprintf(fid, ' \\\\\n');
    fprintf(fid, '\\midrule\n');
    fprintf(fid, '\\endhead\n\n');

    fprintf(fid, '\\midrule\n');
    fprintf(fid, '\\multicolumn{%d}{r}{Continued on next page}\\\\\n', numAlgorithms + 1);
    fprintf(fid, '\\endfoot\n\n');

    fprintf(fid, '\\bottomrule\n');
    fprintf(fid, '\\endlastfoot\n\n');

    % Data rows
    for i = 1:numProblems
        probName = problemSubset{i};
        fprintf(fid, '%s', escapeLatex(probName));

        for j = 1:numAlgorithms
            cellStr = cellStrs{i,j};
            if bestIdx(i) == j && ~strcmp(cellStr, 'N/A')
                fprintf(fid, ' & \\textbf{%s}', cellStr);
            else
                fprintf(fid, ' & %s', cellStr);
            end
        end
        fprintf(fid, ' \\\\\n');
    end

    fprintf(fid, '\\end{longtable}\n');
    fprintf(fid, '\\vspace{1em}\n\n');
end

%% ==================== Data Loading ====================

function values = loadMetricValues(baseDir, algorithmName, mapVarName, problemName)
%LOADMETRICVALUES Load metric values for one (algorithm, problem) pair.
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
