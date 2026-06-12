function generateConvergencePlots(algorithms, problemNames, isFeasible, params) %#ok<INUSD>
%GENERATECONVERGENCEPLOTS Generate convergence and performance-cost plots PDF.
%
%   generateConvergencePlots(algorithms, problemNames, isFeasible, params)
%
%   Produces two types of plots per problem, assembled into a PDF:
%
%     Type A — Metric vs Function Evaluations (Anytime Performance):
%       Feasible: Normalized HV (y) vs FE (x), mean +/- std shaded bands
%       Infeasible: Average CV (y) vs FE (x), mean +/- std shaded bands
%
%     Type B — Performance-Cost Tradeoff:
%       Scatter: x = mean runtime, y = mean AUC, one point per algorithm
%
%   Algorithm display names follow the {MOEA}-HVGSA-{suffix} convention
%   (see getAlgorithmDisplayName). Algorithms are grouped by ablation
%   family (Me/Mi/Ma/U/R/...) and the group is encoded visually:
%     Type A — different line styles per group
%     Type B — different marker shapes per group
%
%   Input:
%     algorithms   - Cell array of algorithm specs
%     problemNames - Cell array of problem name strings
%     isFeasible   - Logical vector (true = feasible)
%     params       - Struct with fields: FE, N, runs (reserved)
%
%   Output:
%     Writes vector PDFs to ./ConvergencePlots/
%     Writes ./ConvergencePlots.tex and compiles to ./ConvergencePlots.pdf

    fprintf('=== Generating Convergence Plots ===\n');

    algorithmNames = cellfun(@(a) getAlgorithmName(a), algorithms, ...
        'UniformOutput', false);
    displayNames   = cellfun(@(n) getAlgorithmDisplayName(n), algorithmNames, ...
        'UniformOutput', false);
    groupKeys      = cellfun(@(n) getAlgorithmGroupKey(n), algorithmNames, ...
        'UniformOutput', false);

    numAlg  = numel(algorithmNames);
    numProb = numel(problemNames);
    amDir   = './AnytimeMetrics';
    plotDir = './ConvergencePlots';

    if ~exist(plotDir, 'dir')
        mkdir(plotDir);
    end

    %% Per-algorithm visual styles (color unique; line style / marker by group)
    styles = buildAlgorithmStyles(groupKeys);

    %% Phase 1 & 2: Generate plot images for each problem
    for pi = 1:numProb
        probName = problemNames{pi};
        feasible = isFeasible(pi);

        fprintf('  [%d/%d] %s ...', pi, numProb, probName);

        %% --- Type A: Convergence curve (metric vs FE) ---
        generateTypeAPlot(probName, feasible, algorithmNames, displayNames, ...
            numAlg, amDir, styles, plotDir);

        %% --- Type B: Performance-cost scatter ---
        generateTypeBPlot(probName, feasible, algorithmNames, displayNames, ...
            numAlg, styles, plotDir);

        fprintf(' done\n');
    end

    %% Phase 3: Assemble LaTeX document
    texPath = './ConvergencePlots.tex';
    fid = fopen(texPath, 'w');
    if fid == -1
        error('Could not open %s for writing.', texPath);
    end
    cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

    writePreamble(fid);

    figCount = 0;
    for pi = 1:numProb
        probName = problemNames{pi};
        feasible = isFeasible(pi);

        typeAFile = fullfile(plotDir, sprintf('Convergence-%s.pdf', probName));
        typeBFile = fullfile(plotDir, sprintf('PerfCost-%s.pdf', probName));
        hasA = exist(typeAFile, 'file') == 2;
        hasB = exist(typeBFile, 'file') == 2;

        if ~hasA && ~hasB
            continue;
        end

        if feasible
            metricLabel = 'HV';
        else
            metricLabel = 'Avg. CV';
        end

        % One figure* per problem with Type A and Type B side by side
        fprintf(fid, '\\begin{figure*}[!t]\n');
        fprintf(fid, '\\centering\n');

        if hasA && hasB
            fprintf(fid, '\\begin{minipage}{0.48\\linewidth}\n');
            fprintf(fid, '\\centering\n');
            fprintf(fid, '\\includegraphics[width=\\linewidth]{%s}\n', ...
                strrep(typeAFile, '\', '/'));
            fprintf(fid, '\\subcaption{%s convergence}\n', metricLabel);
            fprintf(fid, '\\end{minipage}\n');
            fprintf(fid, '\\hfill\n');
            fprintf(fid, '\\begin{minipage}{0.48\\linewidth}\n');
            fprintf(fid, '\\centering\n');
            fprintf(fid, '\\includegraphics[width=\\linewidth]{%s}\n', ...
                strrep(typeBFile, '\', '/'));
            fprintf(fid, '\\subcaption{Performance--cost tradeoff}\n');
            fprintf(fid, '\\end{minipage}\n');
        elseif hasA
            fprintf(fid, '\\includegraphics[width=0.6\\linewidth]{%s}\n', ...
                strrep(typeAFile, '\', '/'));
        else
            fprintf(fid, '\\includegraphics[width=0.6\\linewidth]{%s}\n', ...
                strrep(typeBFile, '\', '/'));
        end

        fprintf(fid, '\\caption{%s --- %s convergence and performance--cost tradeoff.}\n', ...
            escapeLatex(getProblemDisplayName(probName)), metricLabel);
        fprintf(fid, '\\label{fig:conv-%s}\n', lower(probName));
        fprintf(fid, '\\end{figure*}\n\n');

        figCount = figCount + 1;
        if mod(figCount, 3) == 0
            fprintf(fid, '\\clearpage\n\n');
        end
    end

    fprintf(fid, '\\end{document}\n');

    fprintf('  Written to: %s\n', texPath);

    %% Compile LaTeX
    fprintf('  Compiling LaTeX...\n');
    [status, cmdout] = system('pdflatex -interaction=nonstopmode ConvergencePlots.tex');
    if status == 0
        fprintf('  Compilation successful: ConvergencePlots.pdf\n');
    else
        fprintf('  LaTeX compilation failed:\n%s\n', cmdout);
    end

    fprintf('=== Convergence plots generation complete ===\n');
end

%% ==================== Style Assignment ====================

function styles = buildAlgorithmStyles(groupKeys)
%BUILDALGORITHMSTYLES Assign a visual style per algorithm based on its group.
%
%   Returns a struct array (one per algorithm) with fields:
%     color     - 3-vector RGB
%     lineStyle - '-', '--', ':', or '-.'
%     marker    - 'o', 's', '^', 'd', 'v', 'p', ...
%
%   Line styles and markers cycle through a fixed palette in the order
%   each unique group first appears. Colors are distinct per algorithm
%   using MATLAB's 'lines' palette, so algorithms within the same group
%   share a line style / marker but differ in hue.

    lineStylePalette = {'-', '--', ':', '-.'};
    markerPalette    = {'o', 's', '^', 'd', 'v', 'p', 'h', '>', '<', 'x'};

    numAlg  = numel(groupKeys);
    colors  = lines(numAlg);

    [~, ia, ic] = unique(groupKeys, 'stable');   %#ok<ASGLU>
    % ic(k) gives the group index (1..numGroups) for algorithm k.

    styles = repmat(struct('color',[0 0 0], 'lineStyle','-', 'marker','o'), ...
        1, numAlg);
    for k = 1:numAlg
        gIdx = ic(k);
        styles(k).color     = colors(k, :);
        styles(k).lineStyle = lineStylePalette{mod(gIdx-1, numel(lineStylePalette)) + 1};
        styles(k).marker    = markerPalette{   mod(gIdx-1, numel(markerPalette))    + 1};
    end
end

%% ==================== Type A: Convergence Curve ====================

function generateTypeAPlot(probName, feasible, algorithmNames, displayNames, ...
    numAlg, amDir, styles, plotDir)
%GENERATETYPEAPLOT Plot metric vs FE with mean +/- std shaded bands.
%

    PreprocessProductionImage(0.5, 0.75, 6.6);
    fig = gcf;
    ax = gca;
    hold(ax, 'on');
    grid(ax, 'on');
    box(ax, 'on');

    legendHandles = [];
    legendLabels  = {};
    hasData = false;

    for ai = 1:numAlg
        algName = algorithmNames{ai};

        [allFE, allMetrics] = loadAnytimeData(amDir, algName, probName);
        if isempty(allMetrics), continue; end

        [commonFE, meanMetric, stdMetric] = interpolateRuns(allFE, allMetrics);
        if isempty(commonFE), continue; end

        hasData = true;
        col = styles(ai).color;
        ls  = styles(ai).lineStyle;
        mk  = styles(ai).marker;

        % Emphasize the primary algorithm (NSGA-II-HVGSA, no suffix).
        isPrimary  = strcmp(displayNames{ai}, 'NSGA-II-HVGSA');
        if isPrimary
            lineWidth  = 7.0;
            markerSize = 28;
            bandAlpha  = 0.28;
        else
            lineWidth  = 3.5;
            markerSize = 16;
            bandAlpha  = 0.10;
        end

        % Sparse on-line markers (~8 per curve) reinforce the group shape.
        nPts   = numel(commonFE);
        nMarks = min(8, nPts);
        markerIdx = unique(round(linspace(1, nPts, nMarks)));

        h = plot(ax, commonFE, meanMetric, ...
            'Color', col, 'LineStyle', ls, 'LineWidth', lineWidth, ...
            'Marker', mk, 'MarkerSize', markerSize, ...
            'MarkerFaceColor', col, 'MarkerEdgeColor', 'k', ...
            'MarkerIndices', markerIdx);

        upper = meanMetric + stdMetric;
        lower = meanMetric - stdMetric;
        xFill = [commonFE, fliplr(commonFE)];
        yFill = [upper,    fliplr(lower)];
        fill(ax, xFill, yFill, col, 'FaceAlpha', bandAlpha, 'EdgeColor', 'none', ...
            'HandleVisibility', 'off');

        legendHandles(end+1) = h; %#ok<AGROW>
        legendLabels{end+1}  = displayNames{ai}; %#ok<AGROW>
    end

    if feasible
        yLabelBase = 'Normalized HV';
    else
        yLabelBase = 'Average CV';
        yscale log
    end
    title(ax, strrep(getProblemDisplayName(probName), '_', '\_'), ...
        'Interpreter', 'latex');

    if ~isempty(legendHandles)
        legend(ax, legendHandles, legendLabels, 'Location', 'eastoutside', ...
            'Interpreter', 'latex', 'Box', 'on');
    end

    drawnow;
    applyAxisExponentLabels(ax, 'Function Evaluations', yLabelBase);

    hold(ax, 'off');

    
    outPath = fullfile(plotDir, sprintf('Convergence-%s.pdf', probName));
    exportgraphics(fig, outPath, 'ContentType', 'vector');
    close(fig);
end

%% ==================== Type B: Performance-Cost Scatter ====================

function generateTypeBPlot(probName, feasible, algorithmNames, displayNames, ...
    numAlg, styles, plotDir)
%GENERATETYPEBPLOT Scatter plot: mean runtime (x) vs mean AUC (y).

    metricDir = './Info/FinalAUC';
    mapVar    = 'prob2auc';
    if feasible
        yLabel = 'AUC of HV';
    else
        yLabel = '$-$AUC of Avg. CV';
    end

    meanMetrics = NaN(1, numAlg);
    meanTimes   = NaN(1, numAlg);

    for ai = 1:numAlg
        metricVals = loadMetricValues(metricDir, algorithmNames{ai}, ...
            mapVar, probName);
        if ~isempty(metricVals) && ~all(isnan(metricVals))
            meanMetrics(ai) = mean(metricVals, 'omitnan');
        end

        timeVals = loadMetricValues('./Info/FinalTime', algorithmNames{ai}, ...
            'prob2time', probName);
        if ~isempty(timeVals) && ~all(isnan(timeVals))
            meanTimes(ai) = mean(timeVals, 'omitnan');
        end
    end

    validMask = ~isnan(meanMetrics) & ~isnan(meanTimes);
    if ~any(validMask), return; end

    PreprocessProductionImage(0.5, 0.75, 6.6);
    fig = gcf;
    ax = gca;
    hold(ax, 'on');
    grid(ax, 'on');
    box(ax, 'on');

    legendHandles = [];
    legendLabels  = {};

    for ai = 1:numAlg
        if ~validMask(ai), continue; end

        col = styles(ai).color;
        mk  = styles(ai).marker;

        isPrimary = strcmp(displayNames{ai}, 'NSGA-II-HVGSA');
        if isPrimary
            markerSize = 44;
            edgeWidth  = 3.0;
        else
            markerSize = 26;
            edgeWidth  = 1.5;
        end

        h = plot(ax, meanTimes(ai), meanMetrics(ai), ...
            'LineStyle', 'none', ...
            'Marker', mk, ...
            'MarkerSize', markerSize, ...
            'MarkerFaceColor', col, ...
            'MarkerEdgeColor', 'k', ...
            'LineWidth', edgeWidth);

        legendHandles(end+1) = h; %#ok<AGROW>
        legendLabels{end+1}  = displayNames{ai}; %#ok<AGROW>
    end

    title(ax, strrep(getProblemDisplayName(probName), '_', '\_'), ...
        'Interpreter', 'latex');

    if ~isempty(legendHandles)
        legend(ax, legendHandles, legendLabels, 'Location', 'eastoutside', ...
            'Interpreter', 'latex', 'Box', 'on');
    end

    drawnow;
    applyAxisExponentLabels(ax, 'Mean Runtime (s)', yLabel);

    hold(ax, 'off');

    outPath = fullfile(plotDir, sprintf('PerfCost-%s.pdf', probName));
    exportgraphics(fig, outPath, 'ContentType', 'vector');
    close(fig);
end

%% ==================== Anytime Data Loading ====================

function [allFE, allMetrics] = loadAnytimeData(amDir, algName, probName)
%LOADANYTIMEDATA Load anytime metric files for one (alg, prob) pair.

    allFE = {};
    allMetrics = {};

    algDir = fullfile(amDir, algName);
    if ~exist(algDir, 'dir')
        return;
    end

    matFiles = dir(fullfile(algDir, 'AM_*.mat'));

    pattern = sprintf('^AM_%s_%s(_M\\d+_D\\d+)?_\\d+$', ...
        regexptranslate('escape', algName), ...
        regexptranslate('escape', probName));

    for j = 1:length(matFiles)
        [~, fname, ~] = fileparts(matFiles(j).name);
        if ~isempty(regexp(fname, pattern, 'once'))
            try
                data = load(fullfile(algDir, matFiles(j).name), ...
                    'feValues', 'metricValues');
                allFE{end+1}      = data.feValues;      %#ok<AGROW>
                allMetrics{end+1}  = data.metricValues;  %#ok<AGROW>
            catch
                % skip corrupted files
            end
        end
    end
end

%% ==================== Interpolation ====================

function [commonFE, meanMetric, stdMetric] = interpolateRuns(allFE, allMetrics)
%INTERPOLATERUNS Interpolate all runs onto a common FE grid and compute stats.

    commonFE = [];
    meanMetric = [];
    stdMetric = [];

    if isempty(allFE)
        return;
    end

    nRuns = numel(allFE);
    maxLen = 0;
    refIdx = 1;
    for r = 1:nRuns
        if numel(allFE{r}) > maxLen
            maxLen = numel(allFE{r});
            refIdx = r;
        end
    end

    commonFE = allFE{refIdx};
    nPoints = numel(commonFE);

    interpMatrix = NaN(nRuns, nPoints);
    for r = 1:nRuns
        fe = allFE{r};
        mv = allMetrics{r};

        if numel(fe) < 2
            interpMatrix(r, :) = mv(1);
            continue;
        end

        interpMatrix(r, :) = interp1(fe, mv, commonFE, 'linear', NaN);

        firstValid = find(~isnan(interpMatrix(r, :)), 1);
        if ~isempty(firstValid) && firstValid > 1
            interpMatrix(r, 1:firstValid-1) = interpMatrix(r, firstValid);
        end

        lastValid = find(~isnan(interpMatrix(r, :)), 1, 'last');
        if ~isempty(lastValid) && lastValid < nPoints
            interpMatrix(r, lastValid+1:end) = interpMatrix(r, lastValid);
        end
    end

    meanMetric = mean(interpMatrix, 1, 'omitnan');
    stdMetric  = std(interpMatrix, 0, 1, 'omitnan');
end

%% ==================== Metric Data Loading ====================

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

%% ==================== LaTeX Preamble ====================

function writePreamble(fid)
    fprintf(fid, '\\documentclass[journal]{IEEEtran}\n');
    fprintf(fid, '\\usepackage{booktabs}\n');
    fprintf(fid, '\\usepackage{graphicx}\n');
    fprintf(fid, '\\usepackage{caption}\n');
    fprintf(fid, '\\usepackage{subcaption}\n');
    fprintf(fid, '\n');
    fprintf(fid, '\\begin{document}\n\n');
end

%% ==================== LaTeX Utilities ====================

function escaped = escapeLatex(str)
    escaped = strrep(str, '_', '\_');
    escaped = strrep(escaped, '&', '\&');
    escaped = strrep(escaped, '%%', '\%%');
    escaped = strrep(escaped, '#', '\#');
end
