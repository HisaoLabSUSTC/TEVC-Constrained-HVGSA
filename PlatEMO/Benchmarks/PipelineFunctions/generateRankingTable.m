function generateRankingTable(algorithms, problemNames, isFeasible)
%GENERATERANKINGTABLE Generate flat LaTeX ranking table from average rank CSVs.
%
%   generateRankingTable(algorithms, problemNames, isFeasible)
%
%   Reads ranks_*.csv files from ./CDPlots/ (output by generateCDPlots.py)
%   and produces a flat table* environment with columns:
%     Algorithm | Rank(HV) | Rank(AUC-HV) | Rank(CV) | Rank(-AUC-CV)
%
%   Best rank per column is \textbf{}, worst is \underline{}.
%
%   Input:
%     algorithms   - Cell array of algorithm specs (for display name ordering)
%     problemNames - Cell array of problem name strings
%     isFeasible   - Logical vector (true = feasible)
%
%   Output:
%     Writes ./CDPlots/RankingTable.tex (a fragment, not a full document)

    fprintf('  Generating ranking table...\n');

    outDir = './CDPlots';
    hasFeasible   = any(isFeasible);
    hasInfeasible = any(~isFeasible);

    %% Compute algorithm display names in config order (authoritative row order)
    algorithmNames = cellfun(@(a) getAlgorithmName(a), algorithms, ...
        'UniformOutput', false);
    displayNames   = cellfun(@(n) getAlgorithmDisplayName(n), algorithmNames, ...
        'UniformOutput', false);

    %% Define which rank files to include
    rankFiles = {};
    colHeaders = {};
    if hasFeasible
        rankFiles{end+1}  = fullfile(outDir, 'ranks_hv.csv');
        colHeaders{end+1} = 'HV';
        rankFiles{end+1}  = fullfile(outDir, 'ranks_auc_hv.csv');
        colHeaders{end+1} = 'AUC';
    end
    if hasInfeasible
        rankFiles{end+1}  = fullfile(outDir, 'ranks_cv.csv');
        colHeaders{end+1} = 'Avg. CV';
        rankFiles{end+1}  = fullfile(outDir, 'ranks_auc_cv.csv');
        colHeaders{end+1} = '$-$AUC';
    end
    % Time metric is ranked across all problems (lower-is-better, handled by Python)
    rankFiles{end+1}  = fullfile(outDir, 'ranks_time.csv');
    colHeaders{end+1} = 'Time';

    %% Load rank data from each CSV
    % Each CSV has: algorithm,average_rank
    % We merge them by algorithm name (display name from Python)
    rankData = {};  % cell array of containers.Map

    for f = 1:numel(rankFiles)
        filePath = rankFiles{f};
        if ~exist(filePath, 'file')
            warning('generateRankingTable:MissingFile', ...
                'Rank file not found: %s', filePath);
            rankData{f} = containers.Map();
            continue;
        end

        fid = fopen(filePath, 'r');
        header = fgetl(fid);  %#ok<NASGU> skip header
        map = containers.Map();
        while ~feof(fid)
            line = fgetl(fid);
            if ischar(line) && ~isempty(line)
                parts = strsplit(line, ',');
                if numel(parts) >= 2
                    algName = strtrim(parts{1});
                    rankVal = str2double(parts{2});
                    map(algName) = rankVal;
                end
            end
        end
        fclose(fid);
        rankData{f} = map;
    end

    numMetrics = numel(rankFiles);
    numAlg     = numel(displayNames);

    if numAlg == 0
        warning('generateRankingTable:NoData', 'No algorithms provided.');
        return;
    end

    %% Build rank matrix (numAlg x numMetrics) in config order
    rankMatrix = NaN(numAlg, numMetrics);
    for m = 1:numMetrics
        map = rankData{m};
        for a = 1:numAlg
            if isKey(map, displayNames{a})
                rankMatrix(a, m) = map(displayNames{a});
            end
        end
    end

    %% Find best (min) and worst (max) rank per column
    bestIdx = zeros(1, numMetrics);
    worstIdx = zeros(1, numMetrics);
    for m = 1:numMetrics
        col = rankMatrix(:, m);
        validMask = ~isnan(col);
        if any(validMask)
            [~, bestIdx(m)]  = min(col);
            [~, worstIdx(m)] = max(col);
        end
    end

    %% Compute average rank across all metrics
    avgRank = mean(rankMatrix, 2, 'omitnan');
    [~, bestAvgIdx]  = min(avgRank);
    [~, worstAvgIdx] = max(avgRank);

    %% Write LaTeX fragment
    texPath = fullfile(outDir, 'RankingTable.tex');
    fid = fopen(texPath, 'w');
    if fid == -1
        error('Could not open %s for writing.', texPath);
    end
    cleanupObj = onCleanup(@() fclose(fid));

    % Column spec: l + one c per metric + one c for average
    colSpec = ['l' repmat('c', 1, numMetrics + 1)];
    fprintf(fid, '\\begin{table*}[!t]\n');
    fprintf(fid, '\\centering\n');
    fprintf(fid, '\\caption{Average Friedman-Nemenyi Rankings}\n');
    fprintf(fid, '\\label{tab:friedman-ranks}\n');
    fprintf(fid, '\\begin{tabular}{%s}\n', colSpec);
    fprintf(fid, '\\toprule\n');

    % Header row
    fprintf(fid, 'Algorithm');
    for m = 1:numMetrics
        fprintf(fid, ' & %s', colHeaders{m});
    end
    fprintf(fid, ' & Avg. Rank');
    fprintf(fid, ' \\\\\n');
    fprintf(fid, '\\midrule\n');

    % Data rows
    for a = 1:numAlg
        fprintf(fid, '%s', escapeLatex(displayNames{a}));
        for m = 1:numMetrics
            val = rankMatrix(a, m);
            if isnan(val)
                cellStr = 'N/A';
            else
                cellStr = sprintf('%.2f', val);
            end

            % Bold best, underline worst
            if a == bestIdx(m) && ~isnan(val)
                cellStr = sprintf('\\textbf{%s}', cellStr);
            elseif a == worstIdx(m) && ~isnan(val)
                cellStr = sprintf('\\underline{%s}', cellStr);
            end

            fprintf(fid, ' & %s', cellStr);
        end

        % Average rank column
        avgStr = sprintf('%.2f', avgRank(a));
        if a == bestAvgIdx
            avgStr = sprintf('\\textbf{%s}', avgStr);
        elseif a == worstAvgIdx
            avgStr = sprintf('\\underline{%s}', avgStr);
        end
        fprintf(fid, ' & %s', avgStr);

        fprintf(fid, ' \\\\\n');
    end

    fprintf(fid, '\\bottomrule\n');
    fprintf(fid, '\\end{tabular}\n');
    fprintf(fid, '\\vspace{0.5em}\n');
    fprintf(fid, ['\\parbox{0.95\\textwidth}{\\footnotesize ' ...
        'Average ranks computed via the Friedman test. ' ...
        '\\textbf{Bold}: best rank; \\underline{underlined}: worst rank. ' ...
        'Critical difference diagrams (Holm correction, $\\alpha=0.05$) ' ...
        'are shown in the following figures.}\n']);
    fprintf(fid, '\\end{table*}\n');

    %% Write Holm p-value table
    writeHolmPvalueTable(fid, outDir, displayNames, hasFeasible, hasInfeasible);

    fprintf('    Written: %s\n', texPath);
end

%% ==================== Holm P-value Table ====================

function writeHolmPvalueTable(fid, outDir, displayNames, hasFeasible, hasInfeasible)
%WRITEHOLMPVALUETABLE Write LaTeX table of Holm-adjusted p-values vs reference.
%   The reference algorithm is always the first entry in displayNames
%   (matching the first algorithm in the MATLAB config order).

    %% Define holm files to include
    holmFiles  = {};
    colHeaders = {};
    if hasFeasible
        holmFiles{end+1}  = fullfile(outDir, 'holm_hv.csv');
        colHeaders{end+1} = 'HV';
        holmFiles{end+1}  = fullfile(outDir, 'holm_auc_hv.csv');
        colHeaders{end+1} = 'AUC';
    end
    if hasInfeasible
        holmFiles{end+1}  = fullfile(outDir, 'holm_cv.csv');
        colHeaders{end+1} = 'Avg. CV';
        holmFiles{end+1}  = fullfile(outDir, 'holm_auc_cv.csv');
        colHeaders{end+1} = '$-$AUC';
    end
    holmFiles{end+1}  = fullfile(outDir, 'holm_time.csv');
    colHeaders{end+1} = 'Time';

    numMetrics = numel(holmFiles);
    if numMetrics == 0
        return;
    end

    numAlg = numel(displayNames);
    if numAlg == 0
        return;
    end

    refIdx = 1;  % First algorithm in config order is always the reference

    %% Read each holm CSV
    pvalData  = cell(1, numMetrics);   % alg -> holm_pvalue (NaN = ref)
    friedmanP = NaN(1, numMetrics);

    for f = 1:numMetrics
        filePath = holmFiles{f};
        if ~exist(filePath, 'file')
            pvalData{f} = containers.Map();
            continue;
        end

        fidCSV = fopen(filePath, 'r');
        fgetl(fidCSV); % skip header
        map = containers.Map();
        while ~feof(fidCSV)
            line = fgetl(fidCSV);
            if ischar(line) && ~isempty(line)
                parts = strsplit(line, ',');
                if numel(parts) >= 4
                    algName  = strtrim(parts{1});
                    holmStr  = strtrim(parts{3});
                    friedStr = strtrim(parts{4});

                    if isempty(holmStr)
                        map(algName) = NaN;   % reference (marked by Python)
                    else
                        map(algName) = str2double(holmStr);
                    end

                    if isnan(friedmanP(f))
                        friedmanP(f) = str2double(friedStr);
                    end
                end
            end
        end
        fclose(fidCSV);
        pvalData{f} = map;
    end

    %% Build p-value matrix (numAlg x numMetrics) in config order
    pvalMatrix = NaN(numAlg, numMetrics);
    for m = 1:numMetrics
        map = pvalData{m};
        for a = 1:numAlg
            if isKey(map, displayNames{a})
                pvalMatrix(a, m) = map(displayNames{a});
            end
        end
    end

    %% Write table
    fprintf(fid, '\n');
    colSpec = ['l' repmat('c', 1, numMetrics)];
    fprintf(fid, '\\begin{table*}[!t]\n');
    fprintf(fid, '\\centering\n');
    fprintf(fid, '\\caption{Holm-adjusted $p$-values vs.\\ Reference Algorithm ($\\alpha = 0.05$)}\n');
    fprintf(fid, '\\label{tab:holm-pvalues}\n');
    fprintf(fid, '\\begin{tabular}{%s}\n', colSpec);
    fprintf(fid, '\\toprule\n');

    % Header row
    fprintf(fid, 'Algorithm');
    for m = 1:numMetrics
        fprintf(fid, ' & %s', colHeaders{m});
    end
    fprintf(fid, ' \\\\\n');
    fprintf(fid, '\\midrule\n');

    % Data rows
    for a = 1:numAlg
        fprintf(fid, '%s', escapeLatex(displayNames{a}));
        for m = 1:numMetrics
            if a == refIdx
                cellStr = 'ref.';
            elseif isnan(pvalMatrix(a, m))
                cellStr = 'N/A';
            else
                p = pvalMatrix(a, m);
                cellStr = formatPvalue(p);
                if p < 0.05
                    cellStr = sprintf('\\textbf{%s}', cellStr);
                end
            end
            fprintf(fid, ' & %s', cellStr);
        end
        fprintf(fid, ' \\\\\n');
    end

    fprintf(fid, '\\bottomrule\n');
    fprintf(fid, '\\end{tabular}\n');
    fprintf(fid, '\\vspace{0.5em}\n');

    % Footnote: reference algorithm, Friedman p-values, legend
    fprintf(fid, '\\parbox{0.95\\textwidth}{\\footnotesize\n');
    fprintf(fid, 'Reference algorithm: %s.\\\\\n', ...
        escapeLatex(displayNames{refIdx}));

    friedParts = {};
    for m = 1:numMetrics
        if ~isnan(friedmanP(m))
            friedParts{end+1} = sprintf('%s: $%s$', ...
                colHeaders{m}, formatPvalue(friedmanP(m))); %#ok<AGROW>
        end
    end
    fprintf(fid, 'Friedman test $p$-values: %s.\\\\\n', ...
        strjoin(friedParts, '; '));

    fprintf(fid, '\\textbf{Bold}: $p < 0.05$ (significant difference from the reference).}\n');
    fprintf(fid, '\\end{table*}\n');
end

%% ==================== LaTeX Utilities ====================

function escaped = escapeLatex(str)
%ESCAPELATEX Escape special LaTeX characters in a string.
    escaped = strrep(str, '_', '\_');
    escaped = strrep(escaped, '&', '\&');
    escaped = strrep(escaped, '%', '\%');
    escaped = strrep(escaped, '#', '\#');
end

function str = formatPvalue(p)
%FORMATPVALUE Format a p-value for LaTeX display.
    if p < 0.001
        e = floor(log10(p));
        m = p / 10^e;
        str = sprintf('$%.2f\\times10^{%d}$', m, e);
    else
        str = sprintf('%.4f', p);
    end
end
