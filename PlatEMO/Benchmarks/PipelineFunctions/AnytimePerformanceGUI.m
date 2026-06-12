function AnytimePerformanceGUI(algorithms, problemNames, isFeasible)
%ANYTIMEPERFORMANCEGUI Interactive GUI for visualizing convergence curves.
%
%   AnytimePerformanceGUI(algorithms, problemNames, isFeasible)
%
%   Launches a GUI that plots per-generation metric trajectories:
%     - Mean +/- std error bands across runs for each algorithm
%     - Feasible problems: normalized HV over function evaluations
%     - Infeasible problems: average CV over function evaluations
%
%   Controls:
%     - Problem dropdown: select which problem to visualize
%     - Export button: save current plot as PNG
%
%   Input:
%     algorithms   - Cell array of algorithm specs (handles or config cells)
%     problemNames - Cell array of problem name strings
%     isFeasible   - Logical vector (true = feasible, false = infeasible)

    algorithmNames = cellfun(@(a) getAlgorithmName(a), algorithms, 'UniformOutput', false);
    amDir = './AnytimeMetrics';

    %% Create figure
    fig = figure('Name', 'Anytime Performance', ...
        'NumberTitle', 'off', ...
        'Position', [100 100 900 600], ...
        'Color', 'w');

    %% Problem dropdown
    uicontrol(fig, 'Style', 'text', 'String', 'Problem:', ...
        'Position', [20 560 60 20], 'BackgroundColor', 'w', ...
        'HorizontalAlignment', 'left');

    probDropdown = uicontrol(fig, 'Style', 'popupmenu', ...
        'String', problemNames, ...
        'Position', [80 558 200 25], ...
        'Callback', @(src, ~) updatePlot(src, algorithmNames, problemNames, ...
            isFeasible, amDir, fig));

    %% Export button
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Export PNG', ...
        'Position', [300 558 100 25], ...
        'Callback', @(~, ~) exportCurrentPlot(fig, problemNames, probDropdown));

    %% Axes
    ax = axes(fig, 'Position', [0.1 0.12 0.85 0.72]);
    setappdata(fig, 'plotAxes', ax);

    %% Initial plot
    updatePlot(probDropdown, algorithmNames, problemNames, isFeasible, amDir, fig);
end

%% ==================== Update Plot ====================

function updatePlot(src, algorithmNames, problemNames, isFeasible, amDir, fig)
    probIdx = get(src, 'Value');
    probName = problemNames{probIdx};
    feasible = isFeasible(probIdx);

    ax = getappdata(fig, 'plotAxes');
    cla(ax);
    hold(ax, 'on');
    grid(ax, 'on');
    box(ax, 'on');

    % Define colors for up to 10 algorithms
    colors = lines(numel(algorithmNames));
    legendHandles = [];
    legendLabels  = {};

    for ai = 1:numel(algorithmNames)
        algName = algorithmNames{ai};

        % Load all anytime metric files for this (alg, prob)
        [allFE, allMetrics] = loadAnytimeData(amDir, algName, probName);

        if isempty(allMetrics)
            continue;
        end

        % Interpolate all runs onto a common FE grid
        [commonFE, meanMetric, stdMetric] = interpolateRuns(allFE, allMetrics);

        if isempty(commonFE)
            continue;
        end

        % Plot mean line
        col = colors(ai, :);
        h = plot(ax, commonFE, meanMetric, '-', 'Color', col, 'LineWidth', 2);

        % Plot std error band (shaded)
        upper = meanMetric + stdMetric;
        lower = meanMetric - stdMetric;
        xFill = [commonFE, fliplr(commonFE)];
        yFill = [upper, fliplr(lower)];
        fill(ax, xFill, yFill, col, 'FaceAlpha', 0.15, 'EdgeColor', 'none', ...
            'HandleVisibility', 'off');

        legendHandles(end+1) = h; %#ok<AGROW>
        legendLabels{end+1}  = strrep(getAlgorithmDisplayName(algName), '_', '\_'); %#ok<AGROW>
    end

    % Labels and title (use reader-friendly RCM naming)
    probDisplay = getProblemDisplayName(probName);
    if feasible
        yLabelBase = 'Normalized HV';
        titleStr = sprintf('%s — Normalized HV Convergence', probDisplay);
    else
        yLabelBase = 'Average CV';
        titleStr = sprintf('%s — Average CV Convergence', probDisplay);
    end
    title(ax, titleStr, 'Interpreter', 'none');

    if ~isempty(legendHandles)
        legend(ax, legendHandles, legendLabels, 'Location', 'best');
    end

    drawnow;
    applyAxisExponentLabels(ax, 'Function Evaluations', yLabelBase);

    hold(ax, 'off');
end

%% ==================== Data Loading ====================

function [allFE, allMetrics] = loadAnytimeData(amDir, algName, probName)
%LOADANYTIMEDATA Load anytime metric files for one (alg, prob) pair.
%   Returns cell arrays: allFE{r}, allMetrics{r} for each run r.

    allFE = {};
    allMetrics = {};

    algDir = fullfile(amDir, algName);
    if ~exist(algDir, 'dir')
        return;
    end

    % AM files are named AM_{Alg}_{Prob}_M{M}_D{D}_{Run}.mat
    % or AM_{Alg}_{Prob}_{Run}.mat
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

    % Use the FE grid from the run with the most snapshots
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

    % Interpolate each run onto the common grid
    interpMatrix = NaN(nRuns, nPoints);
    for r = 1:nRuns
        fe = allFE{r};
        mv = allMetrics{r};

        if numel(fe) < 2
            interpMatrix(r, :) = mv(1);
            continue;
        end

        % Clamp to the common FE range
        interpMatrix(r, :) = interp1(fe, mv, commonFE, 'linear', NaN);

        % Fill leading NaN with first available value
        firstValid = find(~isnan(interpMatrix(r, :)), 1);
        if ~isempty(firstValid) && firstValid > 1
            interpMatrix(r, 1:firstValid-1) = interpMatrix(r, firstValid);
        end

        % Fill trailing NaN with last available value
        lastValid = find(~isnan(interpMatrix(r, :)), 1, 'last');
        if ~isempty(lastValid) && lastValid < nPoints
            interpMatrix(r, lastValid+1:end) = interpMatrix(r, lastValid);
        end
    end

    meanMetric = mean(interpMatrix, 1, 'omitnan');
    stdMetric  = std(interpMatrix, 0, 1, 'omitnan');
end

%% ==================== Export ====================

function exportCurrentPlot(fig, problemNames, probDropdown)
    probIdx = get(probDropdown, 'Value');
    probName = problemNames{probIdx};

    outDir = './Visualization/images';
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    outPath = fullfile(outDir, sprintf('Anytime-%s.png', probName));
    exportgraphics(fig, outPath, 'Resolution', 300);
    fprintf('Exported: %s\n', outPath);
end
