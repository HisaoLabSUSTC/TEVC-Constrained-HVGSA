function generateFriedmanNemenyiPDF(algorithms, problemNames, isFeasible, params)
%GENERATEFRIEDMANNEMENYIPDF Orchestrate Friedman-Nemenyi analysis pipeline.
%
%   generateFriedmanNemenyiPDF(algorithms, problemNames, isFeasible, params)
%
%   Pipeline:
%     1. Export CSVs via exportCSVforCritDD()
%     2. Run Python generateCDPlots.py to generate CD PDFs and rank CSVs
%     3. Generate ranking table LaTeX via generateRankingTable()
%     4. Assemble final LaTeX document with ranking table + CD plot figures
%     5. Compile to FriedmanNemenyi.pdf via pdflatex
%
%   Input:
%     algorithms   - Cell array of algorithm specs
%     problemNames - Cell array of problem name strings
%     isFeasible   - Logical vector (true = feasible)
%     params       - Struct with fields: FE, N, runs
%
%   Output:
%     Writes ./FriedmanNemenyi.pdf (and intermediate files in ./CDPlots/)

    fprintf('=== Generating Friedman-Nemenyi Analysis ===\n');

    hasFeasible   = any(isFeasible);
    hasInfeasible = any(~isFeasible);

    %% Step 0: Pre-flight — summarise metric-data availability per algorithm
    reportMetricDataAvailability(algorithms, hasFeasible, hasInfeasible);

    %% Step 1: Export CSVs
    fprintf('\n  Step 1: Exporting metric CSVs...\n');
    exportCSVforCritDD(algorithms, problemNames, isFeasible, params);

    %% Step 2: Run Python CD plot generation
    fprintf('\n  Step 2: Running Python CD plot generation...\n');

    % Locate the Python script (same folder as this function)
    scriptDir = fileparts(mfilename('fullpath'));
    pyScript  = fullfile(scriptDir, 'generateCDPlots.py');

    %% Make output dir
    outDir = fullfile(fileparts(scriptDir), '..', 'CDPlots');
    outDir = getAbsPath(outDir);

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    % critdd parent directory (contains the critdd/ package folder)
    critddDir = fullfile(fileparts(scriptDir), '..', 'Visualization', 'critdd');
    critddDir = getAbsPath(critddDir);

    % Build algorithm name mapping for display
    algorithmNames = cellfun(@(a) getAlgorithmName(a), algorithms, ...
        'UniformOutput', false);
    nameMapArgs = buildNameMapArgs(algorithmNames);

    % Get absolute path of CDPlots directory
    cdPlotsAbs = getAbsPath(outDir);

    % Build Python command using conda 'research' environment
    pyCmd = sprintf('conda run -n research --no-capture-output python "%s" "%s" "%s"%s', ...
        pyScript, cdPlotsAbs, critddDir, nameMapArgs);

    fprintf('    Command: %s\n', pyCmd);
    [status, cmdout] = system(pyCmd);

    if status ~= 0
        warning('generateFriedmanNemenyiPDF:PythonFailed', ...
            'Python script failed (exit code %d):\n%s', status, cmdout);
        fprintf('    Python output:\n%s\n', cmdout);
        return;
    else
        fprintf('%s', cmdout);
    end

    %% Step 3: Generate ranking table
    fprintf('\n  Step 3: Generating ranking table LaTeX...\n');
    generateRankingTable(algorithms, problemNames, isFeasible);

    %% Step 4: Assemble final LaTeX document
    fprintf('\n  Step 4: Assembling LaTeX document...\n');
    texPath = './FriedmanNemenyi.tex';
    assembleLatexDocument(texPath, outDir, hasFeasible, hasInfeasible);

    %% Step 5: Compile LaTeX
    fprintf('\n  Step 5: Compiling LaTeX...\n');
    [status, cmdout] = system('pdflatex -interaction=nonstopmode FriedmanNemenyi.tex');
    if status == 0
        fprintf('  Compilation successful: FriedmanNemenyi.pdf\n');
    else
        fprintf('  LaTeX compilation failed:\n%s\n', cmdout);
    end

    fprintf('=== Friedman-Nemenyi analysis complete ===\n');
end

%% ==================== LaTeX Assembly ====================

function assembleLatexDocument(texPath, cdDir, hasFeasible, hasInfeasible)
%ASSEMBLELATEXDOCUMENT Write the final LaTeX document combining table + CD plots.

    fid = fopen(texPath, 'w');
    if fid == -1
        error('Could not open %s for writing.', texPath);
    end
    cleanupObj = onCleanup(@() fclose(fid));

    %% Preamble
    fprintf(fid, '\\documentclass[journal]{IEEEtran}\n');
    fprintf(fid, '\\usepackage{booktabs}\n');
    fprintf(fid, '\\usepackage{amsmath}\n');
    fprintf(fid, '\\usepackage{graphicx}\n');
    fprintf(fid, '\\usepackage{caption}\n');
    fprintf(fid, '\\usepackage[table]{xcolor}\n');
    fprintf(fid, '\n');
    fprintf(fid, '\\begin{document}\n\n');

    %% Include ranking table
    rankTablePath = fullfile(cdDir, 'RankingTable.tex');
    if exist(rankTablePath, 'file')
        % Use forward slashes for LaTeX path compatibility
        latexPath = strrep(rankTablePath, '\', '/');
        fprintf(fid, '\\input{%s}\n\n', latexPath);
    end

    %% Include CD plot figures
    if hasFeasible
        writeCDFigure(fid, cdDir, 'cd_hv.pdf', ...
            'Critical Difference Diagram --- Normalized HV (Feasible Problems)', ...
            'fig:cd-hv');
        writeCDFigure(fid, cdDir, 'cd_auc_hv.pdf', ...
            'Critical Difference Diagram --- AUC of Normalized HV (Feasible Problems)', ...
            'fig:cd-auc-hv');
    end

    if hasInfeasible
        writeCDFigure(fid, cdDir, 'cd_cv.pdf', ...
            'Critical Difference Diagram --- Average CV (Infeasible Problems)', ...
            'fig:cd-cv');
        writeCDFigure(fid, cdDir, 'cd_auc_cv.pdf', ...
            'Critical Difference Diagram --- $-$AUC of Average CV (Infeasible Problems)', ...
            'fig:cd-auc-cv');
    end

    % Runtime CD plot (all problems)
    writeCDFigure(fid, cdDir, 'cd_time.pdf', ...
        'Critical Difference Diagram --- Runtime (All Problems)', ...
        'fig:cd-time');

    %% End document
    fprintf(fid, '\\end{document}\n');

    fprintf('    Written: %s\n', texPath);
end

function writeCDFigure(fid, cdDir, pdfName, caption, label)
%WRITECDFIGURE Write one figure* environment for a CD plot PDF.
    pdfPath = fullfile(cdDir, pdfName);
    if ~exist(pdfPath, 'file')
        fprintf('    Skipping %s (not found)\n', pdfName);
        return;
    end

    % Use forward slashes for LaTeX path compatibility
    latexPath = strrep(pdfPath, '\', '/');

    fprintf(fid, '\\begin{figure*}[!t]\n');
    fprintf(fid, '\\centering\n');
    fprintf(fid, '\\includegraphics[width=0.85\\textwidth]{%s}\n', latexPath);
    fprintf(fid, '\\caption{%s}\n', caption);
    fprintf(fid, '\\label{%s}\n', label);
    fprintf(fid, '\\end{figure*}\n\n');
end

%% ==================== Utilities ====================

function nameMapArgs = buildNameMapArgs(algorithmNames)
%BUILDNAMEMAPARGS Build --name-map arguments for the Python script.
%   Maps internal algorithm names to LaTeX-friendly display names via the
%   shared getAlgorithmDisplayName transform (e.g. 'NSGA-II-CHVGSAMe3' ->
%   'NSGA-II-HVGSA-Me3', 'NSGAIIwH' -> 'NSGA-II'). Only emits a mapping
%   when the display name differs from the internal name. Each pair is
%   double-quoted so hyphens/slashes in display names (e.g. 'C-MOEA/D')
%   don't get parsed as option flags by argparse.

    nameMapArgs = '';
    hasMapping  = false;
    for i = 1:numel(algorithmNames)
        alg     = algorithmNames{i};
        display = getAlgorithmDisplayName(alg);
        if strcmp(alg, display)
            continue;
        end
        if ~hasMapping
            nameMapArgs = ' --name-map';
            hasMapping  = true;
        end
        nameMapArgs = sprintf('%s "%s=%s"', nameMapArgs, alg, display);
    end
end

function absPath = getAbsPath(relPath)
    absPath = char(java.io.File(relPath).getCanonicalPath());
end

%% ==================== Pre-flight Diagnostic ====================

function reportMetricDataAvailability(algorithms, hasFeasible, hasInfeasible)
%REPORTMETRICDATAAVAILABILITY Print a matrix of which per-algorithm metric
%   files are present on disk before attempting CSV export. Helps diagnose
%   empty-output errors that otherwise surface only in the Python step.

    algorithmNames = cellfun(@(a) getAlgorithmName(a), algorithms, ...
        'UniformOutput', false);

    checks = {};
    if hasFeasible
        checks{end+1} = struct('dir','./Info/FinalHV',   'file','prob2hv.mat',  'label','HV');
        checks{end+1} = struct('dir','./Info/FinalAUC',  'file','prob2auc.mat', 'label','AUC');
    end
    if hasInfeasible
        checks{end+1} = struct('dir','./Info/FinalCV',   'file','prob2cv.mat',  'label','CV');
    end
    checks{end+1}     = struct('dir','./Info/FinalTime', 'file','prob2time.mat','label','Time');

    fprintf('  Metric data availability (per algorithm):\n');
    fprintf('    %-34s', 'Algorithm');
    for c = 1:numel(checks)
        fprintf('  %-5s', checks{c}.label);
    end
    fprintf('\n');

    anyMissing = false;
    for a = 1:numel(algorithmNames)
        alg = algorithmNames{a};
        fprintf('    %-34s', alg);
        for c = 1:numel(checks)
            p = fullfile(checks{c}.dir, alg, checks{c}.file);
            if exist(p, 'file')
                fprintf('  %-5s', 'OK');
            else
                fprintf('  %-5s', '--');
                anyMissing = true;
            end
        end
        fprintf('\n');
    end

    if anyMissing
        fprintf(['    Note: "--" = missing metric file. Run ' ...
                 'computeAllMetrics / computeTimeMetrics for those ' ...
                 'algorithms before Direction 4.\n']);
    end
end
