function visualizeResults(algorithms, problemHandles, problemNames, isFeasible)
%VISUALIZERESULTS Generate publication-quality plots for median run populations
%
%   visualizeResults(algorithms, problemHandles, problemNames, isFeasible)
%
%   For each feasible problem (which has a reference PF), visualizes the
%   median-run population overlaid on the reference Pareto front.
%   Supports 2-objective and 3-objective problems (skips M > 3).
%
%   Input:
%     algorithms     - Cell array of algorithm specs (handles or config cells)
%     problemHandles - Cell array of problem function handles
%     problemNames   - Cell array of problem name strings
%     isFeasible     - Logical vector (true = feasible, false = infeasible)
%
%   Output:
%     Saves PNG images to ./Visualization/images/:
%       Pop-{alg}-{prob}.png   — population scatter with PF overlay
%       PF-{prob}.png          — standalone reference PF plot

    fprintf('=== Generating Visualizations ===\n');

    config = struct(...
        'medianDir', './Info/MedianResults', ...
        'dataDir',   './Data', ...
        'boundDir',  './Info/Bounds', ...
        'outputDir', './Visualization/images');

    ensureDirExists(config.boundDir);
    ensureDirExists(config.outputDir);

    %% Get algorithm names
    algorithmNames = cellfun(@(a) getAlgorithmName(a), algorithms, 'UniformOutput', false);

    %% Only visualize feasible problems (which have reference PFs)
    feasibleIdx = find(isFeasible);
    feasibleNames = problemNames(isFeasible);

    if isempty(feasibleNames)
        fprintf('No feasible problems to visualize.\n');
        return;
    end

    %% Load median metadata for all algorithms
    [allResults, allProblems] = loadMedianMetadata(algorithmNames, config);

    if isempty(allProblems)
        warning('No median run data found. Run extractMedianRun() first.');
        return;
    end

    %% Visualize median populations for each feasible problem
    for fi = 1:numel(feasibleNames)
        prob = feasibleNames{fi};
        probField = matlab.lang.makeValidName(prob);

        % Check if any algorithm has data for this problem
        if ~ismember(probField, allProblems)
            fprintf('Skipping %s: no median data found.\n', prob);
            continue;
        end

        fprintf('\n=============================================\n');
        fprintf('Processing Problem: %s (%d/%d)\n', prob, fi, numel(feasibleNames));
        fprintf('=============================================\n');

        % Load reference PF
        PF = loadPFSafe(prob);

        % Determine M from reference PF or first available population
        M = getMFromData(probField, algorithmNames, allResults, config, PF);
        if M > 3
            fprintf('  Skipping %s: M=%d > 3, cannot visualize.\n', prob, M);
            continue;
        end

        % Compute or load axis bounds (consistent across all algorithms)
        bounds = loadOrComputeBounds(probField, algorithmNames, allResults, config, PF);
        if isempty(bounds)
            warning('Could not compute bounds for %s. Skipping.', prob);
            continue;
        end

        % Visualize each algorithm on this problem
        for ai = 1:numel(algorithmNames)
            algName = algorithmNames{ai};
            if ~hasData(allResults, algName, probField)
                continue;
            end
            visualizeSingleResult(algName, probField, bounds, PF, allResults, config);
        end
    end

    %% Draw standalone Pareto front images
    fprintf('\n=== Drawing Reference Pareto Fronts ===\n');
    for fi = 1:numel(feasibleIdx)
        idx = feasibleIdx(fi);
        prob = problemNames{idx};

        PF = loadPFSafe(prob);
        if isempty(PF)
            fprintf('  Skipping PF for %s: no reference PF found.\n', prob);
            continue;
        end

        M = size(PF, 2);
        if M > 3
            continue;
        end

        drawStandalonePF(prob, PF, M, config.outputDir);
    end

    fprintf('\n=== Visualization completed ===\n');
end

%% ==================== METADATA LOADING ====================

function [allResults, allProblems] = loadMedianMetadata(algorithmNames, config)
%LOADMEDIANMETADATA Load median run metadata for all algorithms.
    allResults = struct();
    allProblems = {};

    for ai = 1:numel(algorithmNames)
        algName = algorithmNames{ai};
        medFile = fullfile(config.medianDir, sprintf('Median_%s.mat', algName));

        if ~exist(medFile, 'file')
            warning('Median file missing: %s', medFile);
            continue;
        end

        medData = load(medFile);
        validName = matlab.lang.makeValidName(algName);
        allResults.(validName) = medData.results;
        allResults.(validName).originalName = algName;

        % Collect all problem fields (excluding 'originalName')
        fields = fieldnames(medData.results);
        allProblems = union(allProblems, fields);
    end
end

function tf = hasData(allResults, algName, probField)
    validName = matlab.lang.makeValidName(algName);
    tf = isfield(allResults, validName) && isfield(allResults.(validName), probField);
end

function dataPath = getDataPath(algName, probField, allResults, config)
    validName = matlab.lang.makeValidName(algName);
    medianFile = allResults.(validName).(probField).medianFile;

    if ~isempty(medianFile)
        % Use the filename stored by extractMedianRun (found via dir scan)
        dataPath = fullfile(config.dataDir, algName, medianFile);
    else
        % medianFile is empty (extractMedianRun couldn't find it) — try
        % to resolve now by scanning the Data directory
        medianIdx = allResults.(validName).(probField).medianIdx;
        % Recover original problem name from the field name
        probName = probField;  % for RWMOP names, makeValidName is identity
        dataPath = resolveDataFile(config.dataDir, algName, probName, medianIdx);
    end
end

function dataPath = resolveDataFile(dataDir, algName, probName, runIdx)
%RESOLVEDATAFILE Find actual data file by scanning Data directory.
%   Handles both PlatEMO naming conventions:
%     {Alg}_{Prob}_{Run}.mat  and  {Alg}_{Prob}_M{M}_D{D}_{Run}.mat
    dataPath = '';
    algDir = fullfile(dataDir, algName);
    if ~exist(algDir, 'dir')
        return;
    end

    matFiles = dir(fullfile(algDir, '*.mat'));
    pattern = sprintf('^%s_%s(_M\\d+_D\\d+)?_\\d+$', ...
        regexptranslate('escape', algName), ...
        regexptranslate('escape', probName));

    files = {};
    for j = 1:length(matFiles)
        [~, fname, ~] = fileparts(matFiles(j).name);
        if ~isempty(regexp(fname, pattern, 'once'))
            files{end+1} = matFiles(j).name; %#ok<AGROW>
        end
    end
    files = sort(files);

    if runIdx <= numel(files)
        dataPath = fullfile(algDir, files{runIdx});
    end
end

%% ==================== PF LOADING ====================

function PF = loadPFSafe(probName)
%LOADPFSAFE Load reference PF, returning empty on failure.
    PF = [];
    try
        [PF, ~, ~] = loadReferencePF(probName);
    catch
        fprintf('  Warning: Could not load reference PF for %s\n', probName);
    end
end

function M = getMFromData(probField, algorithmNames, allResults, config, PF)
%GETMFROMDATA Determine number of objectives from PF or population data.
    M = 0;
    if ~isempty(PF)
        M = size(PF, 2);
        return;
    end
    % Fallback: load first available population
    for ai = 1:numel(algorithmNames)
        algName = algorithmNames{ai};
        if ~hasData(allResults, algName, probField)
            continue;
        end
        dataPath = getDataPath(algName, probField, allResults, config);
        if exist(dataPath, 'file')
            data = load(dataPath, 'result');
            if isfield(data, 'result')
                lastPop = data.result{end, 2};
                M = size(lastPop.objs, 2);
                return;
            end
        end
    end
end

%% ==================== BOUNDS ====================

function bounds = loadOrComputeBounds(probField, algorithmNames, allResults, config, PF)
    boundPath = fullfile(config.boundDir, sprintf('bound-%s.mat', probField));

    if exist(boundPath, 'file')
        fprintf('  Loading existing bounds: %s\n', probField);
        bounds = loadBounds(boundPath);
        return;
    end

    fprintf('  Computing bounds: %s\n', probField);
    bounds = computeBounds(probField, algorithmNames, allResults, config, PF);

    if ~isempty(bounds)
        saveBounds(boundPath, bounds);
    end
end

function bounds = loadBounds(boundPath)
    data = load(boundPath);
    bounds = struct();
    bounds.XBounds = data.XBounds;
    bounds.YBounds = data.YBounds;
    if isfield(data, 'ZBounds')
        bounds.ZBounds = data.ZBounds;
        bounds.M = 3;
    else
        bounds.M = 2;
    end
end

function saveBounds(boundPath, bounds)
    XBounds = bounds.XBounds; %#ok<NASGU>
    YBounds = bounds.YBounds; %#ok<NASGU>
    if bounds.M >= 3
        ZBounds = bounds.ZBounds; %#ok<NASGU>
        save(boundPath, 'XBounds', 'YBounds', 'ZBounds');
    else
        save(boundPath, 'XBounds', 'YBounds');
    end
end

function bounds = computeBounds(probField, algorithmNames, allResults, config, PF)
%COMPUTEBOUNDS Compute global axis bounds from all algorithms' populations + PF.
%   Falls back to PF-only bounds if no data files can be loaded.
    bounds = [];
    globalLow = [];
    globalHigh = [];
    M = 0;
    pfIncluded = false;

    for ai = 1:numel(algorithmNames)
        algName = algorithmNames{ai};
        if ~hasData(allResults, algName, probField)
            continue;
        end

        dataPath = getDataPath(algName, probField, allResults, config);
        if isempty(dataPath) || ~exist(dataPath, 'file')
            fprintf('    Bounds: data file not found for %s on %s\n', algName, probField);
            continue;
        end

        data = load(dataPath, 'result');
        if ~isfield(data, 'result')
            continue;
        end

        lastPop = data.result{end, 2};
        objs = lastPop.objs;
        M = size(objs, 2);

        % Include PF once for bound computation
        if ~pfIncluded && ~isempty(PF)
            objs = [objs; PF]; %#ok<AGROW>
            pfIncluded = true;
        end

        [globalLow, globalHigh] = updateBounds(globalLow, globalHigh, objs);
    end

    % Fallback: compute bounds from PF alone if no data files were loaded
    if isempty(globalLow) && ~isempty(PF)
        fprintf('    Bounds: using reference PF only (no data files loaded)\n');
        M = size(PF, 2);
        globalLow = min(PF);
        globalHigh = max(PF);
    end

    if isempty(globalLow)
        return;
    end

    bounds = buildBoundsStruct(globalLow, globalHigh, M);
end

function [globalLow, globalHigh] = updateBounds(globalLow, globalHigh, objs)
    if ~isempty(objs)
        low  = min(objs);
        high = max(objs);
        if isempty(globalLow)
            globalLow  = low;
            globalHigh = high;
        else
            globalLow  = min(globalLow, low);
            globalHigh = max(globalHigh, high);
        end
    end
end

function bounds = buildBoundsStruct(globalLow, globalHigh, M)
    bounds = struct();
    bounds.M = M;
    bounds.XBounds = roundc([globalLow(1), globalHigh(1)]);
    bounds.YBounds = roundc([globalLow(2), globalHigh(2)]);
    if M >= 3
        bounds.ZBounds = roundc([globalLow(3), globalHigh(3)]);
    end
end

function new_interval = roundc(interval)
%ROUNDC Round axis interval to clean tick values.
    range = diff(interval);
    if range == 0
        new_interval = interval;
        return;
    end
    scale = 10^floor(log10(range / 10));
    new_lower = floor(interval(1) / scale) * scale;
    new_upper = ceil(interval(2) / scale) * scale;
    new_interval = [new_lower, new_upper];
end

%% ==================== POPULATION VISUALIZATION ====================

function visualizeSingleResult(algName, probField, bounds, PF, allResults, config)
    fprintf('  Visualizing: %s on %s\n', algName, probField);

    dataPath = getDataPath(algName, probField, allResults, config);
    if isempty(dataPath) || ~exist(dataPath, 'file')
        fprintf('    Skipped: data file not found for %s on %s\n', algName, probField);
        return;
    end

    data = load(dataPath, 'result');
    if ~isfield(data, 'result')
        return;
    end

    lastPop = data.result{end, 2};
    objs = lastPop.objs;
    M = size(objs, 2);

    if M > 3
        return;
    end

    % Separate feasible and infeasible solutions for visual distinction
    cons = lastPop.cons;
    if ~isempty(cons)
        totalCV = sum(max(0, cons), 2);
        feasMask = totalCV <= 0;
    else
        feasMask = true(size(objs, 1), 1);
    end

    feasObjs   = objs(feasMask, :);
    infeasObjs = objs(~feasMask, :);

    % Display name for legend (use reader-friendly name)
    algDisplay = strrep(getAlgorithmDisplayName(algName), '_', '\_');

    savePath = fullfile(config.outputDir, sprintf('Pop-%s-%s.png', algName, probField));
    renderPopulation(algDisplay, probField, feasObjs, infeasObjs, PF, bounds, savePath);
end

function renderPopulation(algDisplay, probField, feasObjs, infeasObjs, PF, bounds, savePath)
%RENDERPOPULATION Render a population scatter with PF overlay.

    M = bounds.M;

    PreprocessProductionImage(2/3, 1, 8.8);
    fig = gcf;
    ax = gca;
    cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');

    if M >= 3
        view(ax, 135, 30);
    else
        view(ax, 2);
    end

    % Draw reference PF behind population
    if ~isempty(PF)
        if M == 2
            plot(ax, PF(:,1), PF(:,2), '.k', 'MarkerSize', 3, ...
                'HandleVisibility', 'off');
        else
            plot3(ax, PF(:,1), PF(:,2), PF(:,3), '.k', 'MarkerSize', 5, ...
                'HandleVisibility', 'off');
        end
    end

    % Draw feasible solutions (red filled)
    legendHandles = [];
    legendLabels  = {};

    if ~isempty(feasObjs)
        if M == 2
            h1 = scatter(ax, feasObjs(:,1), feasObjs(:,2), 180, ...
                'r', 'filled', 'MarkerEdgeColor', 'k', ...
                'MarkerFaceAlpha', 1, 'LineWidth', 1.5);
        else
            h1 = scatter3(ax, feasObjs(:,1), feasObjs(:,2), feasObjs(:,3), 180, ...
                'r', 'filled', 'MarkerEdgeColor', 'k', ...
                'MarkerFaceAlpha', 1, 'LineWidth', 1.5);
        end
        legendHandles(end+1) = h1;
        legendLabels{end+1} = sprintf('%s (feasible)', algDisplay);
    end

    % Draw infeasible solutions (blue hollow)
    if ~isempty(infeasObjs)
        if M == 2
            h2 = scatter(ax, infeasObjs(:,1), infeasObjs(:,2), 120, ...
                'b', 'LineWidth', 1.5);
        else
            h2 = scatter3(ax, infeasObjs(:,1), infeasObjs(:,2), infeasObjs(:,3), 120, ...
                'b', 'LineWidth', 1.5);
        end
        legendHandles(end+1) = h2;
        legendLabels{end+1} = sprintf('%s (infeasible)', algDisplay);
    end

    % Apply consistent axis bounds
    set(ax, 'XLim', bounds.XBounds, 'XTick', bounds.XBounds);
    set(ax, 'YLim', bounds.YBounds, 'YTick', bounds.YBounds);
    set(ax, 'XTickLabelRotation', 0, 'YTickLabelRotation', 0);

    if M >= 3 && isfield(bounds, 'ZBounds')
        set(ax, 'ZLim', bounds.ZBounds, 'ZTick', bounds.ZBounds);
        set(ax, 'ZTickLabelRotation', 0);
    end

    % Legend
    if ~isempty(legendHandles)
        legend(ax, legendHandles, legendLabels, 'Location', 'southoutside');
    end

    % Axis styling
    axis(ax, 'square');
    set(ax.Title, 'String', '');

    if M == 2
        set(ax, 'Position', [0.32 0.35 0.36 0.57]);
        if ~isempty(ax.Legend)
            set(ax.Legend, 'Position', [0.3 0.08 0.4 0.1]);
        end
    else
        set(ax, 'Position', [0.2 0.35 0.6 0.6]);
        if ~isempty(ax.Legend)
            set(ax.Legend, 'Position', [0.3 0.08 0.4 0.1]);
        end
    end

    % 3D lighting
    if M == 3
        axis(ax, 'vis3d');
        box(ax, 'on');
        lighting(ax, 'gouraud');
        light('Position', [1 1 1], 'Style', 'infinite');
        light('Position', [-1 -1 -1], 'Style', 'infinite', 'Color', [0.3 0.3 0.3]);
    end

    drawnow;
    if M >= 3
        applyAxisExponentLabels(ax, '$f_1$', '$f_2$', '$f_3$');
    else
        applyAxisExponentLabels(ax, '$f_1$', '$f_2$');
    end

    exportgraphics(fig, savePath, 'Resolution', 300);
    close(fig);
end

%% ==================== STANDALONE PF ====================

function drawStandalonePF(probName, PF, M, outputDir)
%DRAWSTANDALONEPF Draw a standalone reference Pareto front image.

    fprintf('  Drawing PF: %s\n', probName);

    PreprocessProductionImage(2/3, 1, 8.8);
    fig = gcf;
    ax = gca;
    cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
    axis(ax, 'square');

    if M == 2
        plot(ax, PF(:,1), PF(:,2), '.k', 'MarkerSize', 20);
    elseif M == 3
        plot3(ax, PF(:,1), PF(:,2), PF(:,3), '.k', 'MarkerSize', 25);
    end

    if M == 3
        view(ax, 135, 30);
        box(ax, 'on');
        lighting(ax, 'gouraud');
        light('Position', [1 1 1], 'Style', 'infinite');
    else
        view(ax, 2);
    end

    % Legend (use RCM naming for reader-facing label)
    displayName = strrep(getProblemDisplayName(probName), '_', '\_');
    hold on;
    h1 = plot(NaN, NaN, 'Marker', 'none', 'LineStyle', 'none');
    h2 = plot(NaN, NaN, 'Marker', 'none', 'LineStyle', 'none');
    legend([h1, h2], ...
        sprintf('Problem: %s', displayName), ...
        sprintf('$m$ = %d, PF (%d pts)', M, size(PF, 1)), ...
        'Location', 'south', ...
        'Interpreter', 'latex');

    if M == 2
        set(ax, 'Position', [0.32 0.35 0.36 0.57]);
        set(ax.Legend, 'Position', [0.3 0.08 0.4 0.1]);
    else
        set(ax, 'Position', [0.2 0.35 0.6 0.6]);
        set(ax.Legend, 'Position', [0.3 0.08 0.4 0.1]);
    end

    drawnow;
    if M == 3
        applyAxisExponentLabels(ax, '$f_1$', '$f_2$', '$f_3$');
    else
        applyAxisExponentLabels(ax, '$f_1$', '$f_2$');
    end

    filename = fullfile(outputDir, sprintf('PF-%s.png', probName));
    exportgraphics(fig, filename, 'Resolution', 150);
    close(fig);
end

%% ==================== UTILITIES ====================

function ensureDirExists(dirPath)
    if ~exist(dirPath, 'dir')
        mkdir(dirPath);
    end
end
