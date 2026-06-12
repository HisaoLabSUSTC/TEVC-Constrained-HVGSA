%% DASCMaOPPipeline - Scalability pipeline for DAS-CMaOP1
%
%   Modular benchmark pipeline tailored to DAS-CMaOP1, used to investigate
%   algorithm scalability with respect to:
%       - number of objectives m in {5, 8, 10}
%       - number of decision variables n in {2(m-1)+20, 2(m-1)+50, 2(m-1)+100}
%   which yields 9 problem instances, each run <params.runs> times.
%
%   Key design choices (mirrors BenchmarkPipeline.m):
%     - Algorithms are specified the same way (handles or config cells).
%     - DAS-CMaOP1 instances are distinguished by (m, n) using the unique
%       name "DASCMaOP1_M<m>_D<n>". This matches PlatEMO's own file suffix
%       "{class}_M{M}_D{D}_{run}.mat", so raw data on disk is already
%       addressable per-instance without renaming.
%     - HV is computed with the user-specified reference point
%           r = (3, 3, ..., 3, 2m + 1) in the original objective space,
%       applied directly to the feasible subset of the final population.
%     - Difficulty triplet is fixed at [0.25, 0.25, 0.25].
%     - Shared initial populations are generated per (instance, run) pair so
%       wH algorithms start from matching seeds for a fair comparison.
%
%   Outputs:
%     ./Data/{alg}/{alg}_DASCMaOP1_M{m}_D{n}_{run}.mat        (raw PlatEMO)
%     ./Info/FinalTime_DAS/{alg}/prob2time.mat                (runtime map)
%     ./Info/FinalHV_DAS/{alg}/prob2hv.mat                    (HV map, optional)
%     ./Visualization/DASCMaOP_time_vs_m.pdf                  (m vs time, fixed n)
%     ./Visualization/DASCMaOP_time_vs_n.pdf                  (n vs time, fixed m)

%% Add PipelineFunctions to path
addpath(fullfile(fileparts(mfilename('fullpath')), 'PipelineFunctions'));

%% ========================================================================
%  CONFIGURATION
%  ========================================================================

%% Define algorithms to benchmark
% Accepts the same spec formats used by BenchmarkPipeline.m:
%   - function handle (e.g. @NSGAIIwH)
%   - config cell (e.g. generateCHVGSA(...))
algorithms = { ...
    % generateCHVGSA(), ...
    @NSGAIIwH, ...
    @NSGAIIIwH, ...
};

%% DAS-CMaOP instance grid
M_list      = [5, 8, 10];                    % objective counts m
n_offsets   = [28, 34, 38];                 % n = 2*(m-1) + offset
triplet     = [0.25, 0.25, 0.25];            % (eta, zeta, gamma)

%% Benchmark parameters (FE is user-supplied)
params = struct( ...
    'FE',   400000, ...                       % max function evaluations (override as needed)
    'runs', 5);                             % independent runs per instance

%% Direction flags
runTask1_RunBenchmarks      = false;
runTask2_ExtractTimeMetrics = false;
runTask3_ComputeHV          = true;         % HV with user ref point (optional)
runTask4_ScalabilityPlots   = true;
runTask5_WilcoxonPDF        = true;         % Wilcoxon rank-sum PDF (HV + time)

%% Build instance table and per-instance population size
instances = buildInstances(M_list, n_offsets, triplet);
for k = 1:numel(instances)
    instances(k).N = getPopulationSize(instances(k).M);
end

fprintf('Pipeline configured: %d algorithms, %d DAS-CMaOP1 instances, %d runs each\n', ...
    numel(algorithms), numel(instances), params.runs);
for k = 1:numel(instances)
    inst = instances(k);
    fprintf('  %s  (M=%d, D=%d, N=%d, K=%d)\n', ...
        inst.name, inst.M, inst.D, inst.N, inst.K);
end

%% ========================================================================
%  TASK 1: RUN BENCHMARKS
%  ========================================================================
if runTask1_RunBenchmarks
    fprintf('\n=== Task 1: Running DAS-CMaOP1 benchmarks ===\n');
    runDASCMaOPBenchmarks(algorithms, instances, params);
end

%% ========================================================================
%  TASK 2: EXTRACT TIME METRICS
%  ========================================================================
if runTask2_ExtractTimeMetrics
    fprintf('\n=== Task 2: Extracting runtime metrics ===\n');
    extractDASTimeMetrics(algorithms, instances, params.runs);
end

%% ========================================================================
%  TASK 3: COMPUTE HV METRICS (reference point (3,...,3,2m+1))
%  ========================================================================
if runTask3_ComputeHV
    fprintf('\n=== Task 3: Computing HV with user-specified ref point ===\n');
    computeDASHVMetrics(algorithms, instances, params.runs);
end

%% ========================================================================
%  TASK 4: SCALABILITY PLOTS (time vs m/n, HV vs m/n)
%  ========================================================================
if runTask4_ScalabilityPlots
    fprintf('\n=== Task 4a: Plotting runtime scalability (time vs m, time vs n) ===\n');
    plotDASScalability(algorithms, instances, ...
        './Info/FinalTime_DAS', 'prob2time', 'Mean runtime (s)', ...
        'DASCMaOP_time', 'DAS-CMaOP1 runtime scalability');

    if runTask3_ComputeHV
        fprintf('\n=== Task 4b: Plotting HV scalability (HV vs m, HV vs n) ===\n');
        plotDASScalability(algorithms, instances, ...
            './Info/FinalHV_DAS', 'prob2hv', 'Mean normalized HV', ...
            'DASCMaOP_hv', 'DAS-CMaOP1 HV scalability');
    end
end

%% ========================================================================
%  TASK 5: WILCOXON RANK-SUM PDF (HV + runtime)
%  ========================================================================
if runTask5_WilcoxonPDF
    fprintf('\n=== Task 5: Generating Wilcoxon rank-sum PDF ===\n');
    generateDASWilcoxonPDF(algorithms, instances);
end

fprintf('\n========================================\n');
fprintf('DAS-CMaOP PIPELINE COMPLETE\n');
fprintf('========================================\n');

%% ========================================================================
%  LOCAL FUNCTIONS
%  ========================================================================

function inst = buildInstances(M_list, n_offsets, triplet)
% Build a struct array of DAS-CMaOP1 instances (one per (m, n) pair).
    rows = cell(0, 1);
    for i = 1:numel(M_list)
        m = M_list(i);
        for j = 1:numel(n_offsets)
            n = 2 * (m - 1) + n_offsets(j);
            rows{end+1} = struct( ...
                'M',        m, ...
                'D',        n, ...
                'K',        2 * (m - 1), ...
                'triplet',  triplet, ...
                'offset',   n_offsets(j), ...
                'name',     sprintf('DASCMaOP1_M%d_D%d', m, n), ...
                'refPoint', [3 * ones(1, m - 1), 2 * m + 1], ...
                'N',        NaN); %#ok<AGROW>
        end
    end
    inst = [rows{:}];
end

function runDASCMaOPBenchmarks(algorithms, instances, params)
% Execute every (algorithm, instance, run) combination through platemo.
% Uses shared initial populations per (instance, run) pair for wH algos.

    FE   = params.FE;
    runs = params.runs;

    initPopDir = './Info/InitialPopulation';
    if ~exist(initPopDir, 'dir'), mkdir(initPopDir); end

    % Generate shared initial populations
    for k = 1:numel(instances)
        inst = instances(k);
        for r = 1:runs
            hidFile = fullfile(initPopDir, sprintf('HS-%s_%d.mat', inst.name, r));
            if exist(hidFile, 'file'), continue; end
            rng(42 + r);
            lower = zeros(1, inst.D);
            upper = 2:2:2 * inst.D;
            heuristic_solutions = repmat(lower, inst.N, 1) + ...
                rand(inst.N, inst.D) .* repmat(upper - lower, inst.N, 1); %#ok<NASGU>
            save(hidFile, 'heuristic_solutions', '-v6');
        end
    end

    % Build combination list
    [I, A, R] = ndgrid(1:numel(instances), 1:numel(algorithms), 1:runs);
    combos = [I(:), A(:), R(:)];
    total  = size(combos, 1);
    fprintf('Starting %d tasks (%d instances x %d algorithms x %d runs)...\n', ...
        total, numel(instances), numel(algorithms), runs);

    platemo_root = fileparts(which('platemo'));

    parfor t = 1:total
        runOneDASTask(combos(t, :), algorithms, instances, ...
            initPopDir, FE, platemo_root); %#ok<PFBNS>
    end

    fprintf('=== Benchmark completed ===\n');
end

function runOneDASTask(combo, algorithms, instances, initPopDir, FE, platemo_root)
    inst_idx = combo(1);
    alg_idx  = combo(2);
    run_num  = combo(3);
    inst     = instances(inst_idx);
    algSpec  = algorithms{alg_idx};
    algName  = getAlgorithmName(algSpec);

    % Resolve save interval (same convention as BenchmarkPipeline: ceil(FE/N))
    save_interval = ceil(FE / inst.N);

    % Check for existing result (PlatEMO saves as {alg}_{class}_M{M}_D{D}_{run}.mat)
    dataFile = fullfile(platemo_root, 'Data', algName, ...
        sprintf('%s_DASCMaOP1_M%d_D%d_%d.mat', algName, inst.M, inst.D, run_num));
    if exist(dataFile, 'file')
        fprintf('Skipping (exists): %s / %s / run %d\n', algName, inst.name, run_num);
        return;
    end

    % Attach shared initial population path for wH variants
    hidFile = fullfile(initPopDir, sprintf('HS-%s_%d.mat', inst.name, run_num));
    algorithm_with_param = prepareAlgorithmForPlatemo(algSpec, hidFile);

    % Pass DAS-CMaOP1 parameters (K, triplet) via the problem cell
    % problemSpec = {@DASCMaOP1, inst.K, inst.triplet};
    problemSpec = @DASCMaOP1;

    platemo('problem', problemSpec, 'M', inst.M, 'D', inst.D, 'N', inst.N, ...
        'save', save_interval, 'maxFE', FE, ...
        'algorithm', algorithm_with_param, 'run', run_num);

    fprintf('Completed: %s / %s / run %d\n', algName, inst.name, run_num);
end

function extractDASTimeMetrics(algorithms, instances, runs)
% Read metric.runtime from each raw data file and build prob2time map.
    outRoot = './Info/FinalTime_DAS';
    if ~exist(outRoot, 'dir'), mkdir(outRoot); end

    for a = 1:numel(algorithms)
        algName   = getAlgorithmName(algorithms{a});
        prob2time = containers.Map();
        for k = 1:numel(instances)
            inst = instances(k);
            timeVec = NaN(1, runs);
            for r = 1:runs
                f = fullfile('./Data', algName, ...
                    sprintf('%s_DASCMaOP1_M%d_D%d_%d.mat', algName, inst.M, inst.D, r));
                if ~exist(f, 'file'), continue; end
                try
                    d = load(f, 'metric');
                    if isfield(d, 'metric') && isfield(d.metric, 'runtime')
                        timeVec(r) = d.metric.runtime;
                    end
                catch ME
                    warning('extractDASTimeMetrics:loadFailed', ...
                        'Failed to load %s: %s', f, ME.message);
                end
            end
            prob2time(inst.name) = timeVec;
            fprintf('  %s/%s  runs loaded = %d/%d (mean = %.2fs)\n', ...
                algName, inst.name, sum(~isnan(timeVec)), runs, ...
                mean(timeVec, 'omitnan'));
        end
        subdir = fullfile(outRoot, algName);
        if ~exist(subdir, 'dir'), mkdir(subdir); end
        save(fullfile(subdir, 'prob2time.mat'), 'prob2time');
    end
end

function computeDASHVMetrics(algorithms, instances, runs)
% HV of feasible final-population solutions with reference r = (3,...,3,2m+1).
    outRoot = './Info/FinalHV_DAS';
    if ~exist(outRoot, 'dir'), mkdir(outRoot); end

    for a = 1:numel(algorithms)
        algName = getAlgorithmName(algorithms{a});
        prob2hv = containers.Map();
        for k = 1:numel(instances)
            inst = instances(k);
            ref  = inst.refPoint;
            normC = prod(ref);
            hv   = NaN(1, runs);
            for r = 1:runs
                f = fullfile('./Data', algName, ...
                    sprintf('%s_DASCMaOP1_M%d_D%d_%d.mat', algName, inst.M, inst.D, r));
                if ~exist(f, 'file'), continue; end
                try
                    d = load(f, 'result');
                    finalPop = d.result{end, 2};
                    objs = finalPop.objs;
                    cons = finalPop.cons;
                    if isempty(cons)
                        feasObj = objs;
                    else
                        feasMask = sum(max(0, cons), 2) <= 0;
                        feasObj  = objs(feasMask, :);
                    end
                    if isempty(feasObj)
                        hv(r) = 0;
                    else
                        keep = all(feasObj < ref, 2);
                        if any(keep)
                            hv(r) = stk_dominatedhv(feasObj(keep, :), ref)/normC;
                        else
                            hv(r) = 0;
                        end
                    end
                catch ME
                    warning('computeDASHVMetrics:hvFailed', ...
                        'HV failed for %s: %s', f, ME.message);
                end
            end
            prob2hv(inst.name) = hv;
            fprintf('  %s/%s  mean HV = %.4g (ref = [%s])\n', ...
                algName, inst.name, mean(hv, 'omitnan'), num2str(ref));
        end
        subdir = fullfile(outRoot, algName);
        if ~exist(subdir, 'dir'), mkdir(subdir); end
        save(fullfile(subdir, 'prob2hv.mat'), 'prob2hv');
    end
end

function plotDASScalability(algorithms, instances, metricDir, mapVar, yLabelStr, filePrefix, titleRoot)
% Produce two scalability plots for an arbitrary metric:
%   (1) fixed offset (fixed-n family) — x: m,  y: mean(metric)
%   (2) fixed m                       — x: n,  y: mean(metric)
% metricDir / mapVar point to ./Info/<metricDir>/<alg>/<mapVar>.mat
%   which must contain a containers.Map keyed by instance.name.

    outDir = './Visualization';
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    Ms      = unique([instances.M], 'sorted');
    offsets = unique([instances.offset], 'sorted');

    % Load per-algorithm map and assemble a [|M| x |offsets|] matrix
    algData = struct('name', {}, 'vals', {});
    for a = 1:numel(algorithms)
        algName = getAlgorithmName(algorithms{a});
        dispName = algName;
        if exist('getAlgorithmDisplayName', 'file') == 2
            try, dispName = getAlgorithmDisplayName(algName); catch, end %#ok<CTCH>
        end
        f = fullfile(metricDir, algName, [mapVar '.mat']);
        if ~exist(f, 'file')
            warning('plotDASScalability:missing', ...
                'Metric data missing for %s (expected %s). Skipping.', algName, f);
            continue;
        end
        S = load(f);
        if isfield(S, mapVar)
            map = S.(mapVar);
        else
            fn = fieldnames(S);
            map = S.(fn{1});
        end

        vals = NaN(numel(Ms), numel(offsets));
        for iM = 1:numel(Ms)
            for iO = 1:numel(offsets)
                m = Ms(iM);
                n = 2 * (m - 1) + offsets(iO);
                name = sprintf('DASCMaOP1_M%d_D%d', m, n);
                if isKey(map, name)
                    v = map(name);
                    vals(iM, iO) = mean(v, 'omitnan');
                end
            end
        end
        algData(end + 1).name = dispName; %#ok<AGROW>
        algData(end).vals     = vals;
    end

    if isempty(algData)
        warning('plotDASScalability:noData', 'No data available for %s. Skipping plots.', mapVar);
        return;
    end

    markers = {'-o', '-s', '-^', '-d', '-v', '-p', '-x', '-+', '-*'};

    %% Plot 1: x = m, one subplot per fixed offset (fixed-n family)
    fig = figure('Visible', 'off', 'Position', [100 100 420 * numel(offsets) 420]);
    tl  = tiledlayout(1, numel(offsets), 'TileSpacing', 'compact', 'Padding', 'compact'); %#ok<NASGU>
    for iO = 1:numel(offsets)
        nexttile; hold on; grid on;
        for a = 1:numel(algData)
            mk = markers{mod(a - 1, numel(markers)) + 1};
            plot(Ms, algData(a).vals(:, iO), mk, ...
                'DisplayName', algData(a).name, 'LineWidth', 1.4, 'MarkerSize', 7);
        end
        xlabel('Number of objectives m');
        ylabel(yLabelStr);
        title(sprintf('n = 2(m-1) + %d', offsets(iO)));
        legend('Location', 'best', 'Interpreter', 'none');
        set(gca, 'XTick', Ms);
    end
    sgtitle(sprintf('%s: m vs metric (fixed n family)', titleRoot));
    saveFigure(fig, fullfile(outDir, [filePrefix, '_vs_m']));
    close(fig);

    %% Plot 2: x = n, one subplot per fixed m
    fig = figure('Visible', 'off', 'Position', [100 100 420 * numel(Ms) 420]);
    tl  = tiledlayout(1, numel(Ms), 'TileSpacing', 'compact', 'Padding', 'compact'); %#ok<NASGU>
    for iM = 1:numel(Ms)
        nexttile; hold on; grid on;
        m = Ms(iM);
        nVals = 2 * (m - 1) + offsets;
        for a = 1:numel(algData)
            mk = markers{mod(a - 1, numel(markers)) + 1};
            plot(nVals, algData(a).vals(iM, :), mk, ...
                'DisplayName', algData(a).name, 'LineWidth', 1.4, 'MarkerSize', 7);
        end
        xlabel('Number of decision variables n');
        ylabel(yLabelStr);
        title(sprintf('m = %d', m));
        legend('Location', 'best', 'Interpreter', 'none');
        set(gca, 'XTick', nVals);
    end
    sgtitle(sprintf('%s: n vs metric (fixed m)', titleRoot));
    saveFigure(fig, fullfile(outDir, [filePrefix, '_vs_n']));
    close(fig);

    fprintf('  Saved: %s_vs_{m,n}.{pdf,png}\n', fullfile(outDir, filePrefix));
end

function generateDASWilcoxonPDF(algorithms, instances)
% Build a LaTeX PDF with two rank-sum tables:
%     Table 1: Normalized HV          (higher is better)
%     Table 2: Runtime in seconds     (lower  is better)
% Convention (mirrors generateWilcoxonTables.m):
%     - First algorithm in the config is the reference;
%     - it is displayed in the rightmost column;
%     - mean +/- std per cell, best mean per row bolded,
%     - Wilcoxon rank-sum marker (+), (-), (=) vs reference at alpha=0.05.

    algorithmNames = cellfun(@(a) getAlgorithmName(a), algorithms, ...
        'UniformOutput', false);
    displayNames = algorithmNames;
    if exist('getAlgorithmDisplayName', 'file') == 2
        displayNames = cellfun(@(n) safeDisplayName(n), algorithmNames, ...
            'UniformOutput', false);
    end
    numAlg = numel(algorithmNames);

    if numAlg < 2
        warning('generateDASWilcoxonPDF:TooFewAlgorithms', ...
            'Need at least 2 algorithms for Wilcoxon test. Skipping.');
        return;
    end

    % Rotate reference (first) to the last column
    permIdx        = [2:numAlg, 1];
    algorithmNames = algorithmNames(permIdx);
    displayNames   = displayNames(permIdx);
    refAlgIdx      = numAlg;

    problemNames = arrayfun(@(x) string(x.name), instances, 'UniformOutput', true);
    problemNames = cellstr(problemNames(:));

    texPath = './DASCMaOPWilcoxon.tex';
    fid = fopen(texPath, 'w');
    if fid == -1
        error('Could not open %s for writing.', texPath);
    end
    cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

    % Preamble
    fprintf(fid, '\\documentclass[journal]{IEEEtran}\n');
    fprintf(fid, '\\usepackage{booktabs}\n');
    fprintf(fid, '\\usepackage{amsmath}\n');
    fprintf(fid, '\\usepackage{array}\n');
    fprintf(fid, '\\usepackage[table]{xcolor}\n');
    fprintf(fid, '\\usepackage{caption}\n\n');
    fprintf(fid, '\\begin{document}\n\n');

    % Table 1: HV (higher is better)
    fprintf('  Writing Table 1: HV (higher is better)...\n');
    writeDASWilcoxonTable(fid, algorithmNames, displayNames, problemNames, ...
        './Info/FinalHV_DAS', 'prob2hv', ...
        'DAS-CMaOP1: Normalized Hypervolume (Mean $\pm$ Std)', ...
        'tab:das-wilcoxon-hv', '%.4f', ' \pm ', true, refAlgIdx);

    % Table 2: Runtime (lower is better)
    fprintf('  Writing Table 2: Runtime (lower is better)...\n');
    writeDASWilcoxonTable(fid, algorithmNames, displayNames, problemNames, ...
        './Info/FinalTime_DAS', 'prob2time', ...
        'DAS-CMaOP1: Runtime in Seconds (Mean $\pm$ Std)', ...
        'tab:das-wilcoxon-time', '%.2f', ' \pm ', false, refAlgIdx);

    fprintf(fid, '\n\\end{document}\n');

    % Compile
    fprintf('  Compiling LaTeX...\n');
    [status, cmdout] = system('pdflatex -interaction=nonstopmode DASCMaOPWilcoxon.tex');
    if status == 0
        fprintf('  Compilation successful: DASCMaOPWilcoxon.pdf\n');
    else
        fprintf('  LaTeX compilation failed:\n%s\n', cmdout);
    end
end

function writeDASWilcoxonTable(fid, algorithmNames, displayNames, problemNames, ...
    baseDir, mapVarName, caption, label, numFmt, pmLatex, higherIsBetter, refAlgIdx)
% Emit one table* environment for the given metric.

    numAlg  = numel(algorithmNames);
    numProb = numel(problemNames);
    alpha   = 0.05;

    rawData    = cell(numProb, numAlg);
    meanMatrix = NaN(numProb, numAlg);
    stdMatrix  = NaN(numProb, numAlg);

    for i = 1:numProb
        for j = 1:numAlg
            values = loadMetricMap(baseDir, algorithmNames{j}, mapVarName, problemNames{i});
            rawData{i,j} = values;
            if ~isempty(values) && ~all(isnan(values))
                meanMatrix(i,j) = mean(values, 'omitnan');
                stdMatrix(i,j)  = std(values, 0, 'omitnan');
            end
        end
    end

    markers = cell(numProb, numAlg);
    for i = 1:numProb
        for j = 1:numAlg
            if j == refAlgIdx
                markers{i,j} = '';
                continue;
            end
            algVals = rawData{i,j};
            refVals = rawData{i,refAlgIdx};
            if ~isempty(algVals), algVals = algVals(~isnan(algVals)); end
            if ~isempty(refVals), refVals = refVals(~isnan(refVals)); end
            if isempty(algVals) || isempty(refVals)
                markers{i,j} = '';
                continue;
            end
            try
                p = ranksum(algVals(:), refVals(:));
            catch
                markers{i,j} = '$(=)$';
                continue;
            end
            if p < alpha
                algMean = meanMatrix(i,j);
                refMean = meanMatrix(i,refAlgIdx);
                if higherIsBetter
                    if algMean > refMean, markers{i,j} = '$(+)$';
                    else,                 markers{i,j} = '$(-)$'; end
                else
                    if algMean < refMean, markers{i,j} = '$(+)$';
                    else,                 markers{i,j} = '$(-)$'; end
                end
            else
                markers{i,j} = '$(=)$';
            end
        end
    end

    % Wins/losses/ties
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

    % Best per row
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

    % Table
    fprintf(fid, '\\begin{table*}[!t]\n');
    fprintf(fid, '\\centering\n');
    fprintf(fid, '\\caption{%s}\n', caption);
    fprintf(fid, '\\label{%s}\n', label);
    colSpec = ['l' repmat('c', 1, numAlg)];
    fprintf(fid, '\\begin{tabular}{%s}\n', colSpec);
    fprintf(fid, '\\toprule\n');

    fprintf(fid, 'Instance ($m$, $n$)');
    for j = 1:numAlg
        fprintf(fid, ' & %s', escapeLatexSimple(displayNames{j}));
    end
    fprintf(fid, ' \\\\\n');
    fprintf(fid, '\\midrule\n');

    for i = 1:numProb
        rowLabel = prettyInstanceName(problemNames{i});
        fprintf(fid, '%s', rowLabel);
        for j = 1:numAlg
            if isnan(meanMatrix(i,j))
                cellStr = 'N/A';
            else
                mStr = formatCompactLocal(meanMatrix(i,j), numFmt);
                sStr = formatCompactLocal(stdMatrix(i,j),  numFmt);
                cellStr = ['$' mStr pmLatex sStr '$'];
            end
            if bestIdx(i) == j && ~isnan(meanMatrix(i,j))
                cellStr = ['\textbf{' cellStr '}'];
            end
            if ~isempty(markers{i,j})
                cellStr = [cellStr ' ' markers{i,j}];
            end
            fprintf(fid, ' & %s', cellStr);
        end
        fprintf(fid, ' \\\\\n');
    end

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

    if higherIsBetter
        dirStr = 'higher is better';
    else
        dirStr = 'lower is better';
    end
    fprintf(fid, '\\vspace{0.5em}\n');
    fprintf(fid, ['\\parbox{0.95\\textwidth}{\\footnotesize ' ...
        '$(+)$, $(-)$, and $(=)$ indicate that the result is significantly better than, ' ...
        'worse than, or comparable to %s (Wilcoxon rank-sum test, $\\alpha=0.05$; %s). ' ...
        'The best mean per row is bolded.}\n'], ...
        escapeLatexSimple(displayNames{refAlgIdx}), dirStr);

    fprintf(fid, '\\end{table*}\n\n');
end

function values = loadMetricMap(baseDir, algorithmName, mapVarName, problemName)
    values = [];
    algPath = fullfile(baseDir, algorithmName, [mapVarName '.mat']);
    if ~exist(algPath, 'file'), return; end
    data = load(algPath);
    if isfield(data, mapVarName)
        map = data.(mapVarName);
    else
        fn = fieldnames(data);
        if isempty(fn), return; end
        map = data.(fn{1});
    end
    if isa(map, 'containers.Map') && isKey(map, problemName)
        values = map(problemName);
    end
end

function pretty = prettyInstanceName(instanceName)
% DASCMaOP1_M5_D28  ->  DASCMaOP1 ($m=5$, $n=28$)
    tok = regexp(instanceName, '^(.*?)_M(\d+)_D(\d+)$', 'tokens', 'once');
    if ~isempty(tok)
        pretty = sprintf('%s ($m=%s$, $n=%s$)', tok{1}, tok{2}, tok{3});
    else
        pretty = escapeLatexSimple(instanceName);
    end
end

function name = safeDisplayName(algName)
    try
        name = getAlgorithmDisplayName(algName);
    catch
        name = algName;
    end
end

function escaped = escapeLatexSimple(str)
    escaped = strrep(str, '_', '\_');
    escaped = strrep(escaped, '&', '\&');
    escaped = strrep(escaped, '%', '\%');
    escaped = strrep(escaped, '#', '\#');
end

function str = formatCompactLocal(val, numFmt)
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

function saveFigure(fig, pathNoExt)
% Export both a vector PDF and a PNG preview for downstream use.
    try
        exportgraphics(fig, [pathNoExt, '.pdf'], 'ContentType', 'vector');
    catch
        saveas(fig, [pathNoExt, '.pdf']);
    end
    try
        exportgraphics(fig, [pathNoExt, '.png'], 'Resolution', 200);
    catch
        saveas(fig, [pathNoExt, '.png']);
    end
end
