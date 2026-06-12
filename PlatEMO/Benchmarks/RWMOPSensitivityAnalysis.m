%% RWMOPSensitivityAnalysis - Within-RCM sensitivity of HVGSA-MOEA
%
%   Companion analysis to BenchmarkPipeline.m (R2.2 / R3.7 revision point).
%   Relates NSGA-II-HVGSA's within-problem improvement over its baseline
%   (NSGA-II) to each RWMOP instance's structural parameters:
%
%       n   - number of decision variables
%       m   - number of objectives
%      |I|  - number of inequality constraints
%      |E|  - number of equality constraints
%
%   Two outcomes are considered:
%
%       1. Performance improvement
%           Feasible (RWMOP1-35, RWMOP50):   Delta HV = HV_HVGSA - HV_baseline
%                                             (both in [0,1], sign: higher is better)
%           Infeasible (RWMOP36-49):          normalized Delta CV =
%                                             (CV_base - CV_HVGSA) /
%                                             max(|CV_base|, |CV_HVGSA|, eps)
%                                             (in [-1, +1], sign: higher is better)
%
%       2. Computational overhead
%           log10(time_HVGSA / time_baseline)   for all 50 problems
%
%   We report Spearman rank correlation between each (parameter, outcome)
%   pair, using feasible-only or infeasible-only subsets for the HV and CV
%   analyses respectively, and all 50 problems for the time overhead.
%
%   Outputs (written relative to PlatEMO/):
%       Visualization/RWMOP_Sensitivity_Scatter.pdf   2x4 scatter grid
%       Visualization/RWMOP_Sensitivity_Bars.pdf      Sensitivity ranking
%       Info/RWMOP_SensitivityTable.csv               Per-problem data
%       Info/RWMOP_SensitivityCorrelations.csv        Spearman rho / p-values
%
%   Invocation:
%       Run from PlatEMO/ (same CWD convention as BenchmarkPipeline.m) or
%       from the Benchmarks/ directory. Paths are resolved either way.
%
%   Problem-parameter source:
%       PlatEMO/Problems/Multi-objective optimization/RWMOPs/Cal_par.m
%       (arrays hard-coded below to avoid instantiating each PROBLEM object).

clear; clc; close all;

%% ========================================================================
%  Path resolution
%  ========================================================================
scriptDir = fileparts(mfilename('fullpath'));
if isempty(scriptDir)
    scriptDir = pwd;
end
addpath(fullfile(scriptDir, 'PipelineFunctions'));

% Info/ and Visualization/ live under PlatEMO/. Support running the script
% from PlatEMO/ or from PlatEMO/Benchmarks/.
platemoRoot = resolvePlatEMORoot(scriptDir);
infoDir     = fullfile(platemoRoot, 'Info');
visDir      = fullfile(platemoRoot, 'Visualization');
if ~exist(infoDir, 'dir'); mkdir(infoDir); end
if ~exist(visDir,  'dir'); mkdir(visDir);  end

% PreprocessProductionImage lives under Global utilities/Visualization/.
globalUtilsDir = fullfile(platemoRoot, 'Global utilities');
if exist(globalUtilsDir, 'dir')
    addpath(genpath(globalUtilsDir));
end

%% ========================================================================
%  Configuration: which algorithm-baseline pair to analyze
%  ========================================================================
pair.hvgsa    = 'NSGA2CHVGSA';   % NSGA-II-HVGSA (internal name)
pair.baseline = 'NSGAIIwH';      % NSGA-II baseline (internal name)
pair.label    = 'NSGA-II-HVGSA vs.\ NSGA-II';

infeasibleIds = 36:49;
numProblems   = 50;

%% ========================================================================
%  RWMOP problem parameters (mirrors Cal_par.m, prob_k = 1..50)
%  D (n), raw_O (m), gn (|I|), hn (|E|)
%  ========================================================================
D_arr  = [4,5,3,4,4,7,4,7,4,2,3,4,7,5,3,2,6,3,10,4,6,9,6,9,2,3,3,7,7,25,25,25,30,30,30,28,28,28,28,34,34,34,34,34,34,34,18,18,18,6];
M_arr  = [2,2,2,2,2,2,2,3,2,2,5,2,3,2,2,2,3,2,3,2,2,2,2,3,2,2,2,2,2,2,2,2,2,2,2,2,2,2,3,2,3,2,2,3,3,4,2,2,3,2];
gn_arr = [2,5,3,4,4,11,1,9,1,2,7,1,11,8,8,2,9,3,10,7,4,2,1,0,2,1,3,4,9,24,24,24,29,29,29,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
hn_arr = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4,4,6,0,1,0,4,0,0,0,0,0,0,0,24,24,24,24,26,26,26,26,26,26,26,12,12,12,1];

assert(all([numel(D_arr), numel(M_arr), numel(gn_arr), numel(hn_arr)] == numProblems), ...
    'Parameter arrays must have length %d.', numProblems);

isFeasible = true(1, numProblems);
isFeasible(infeasibleIds) = false;

%% ========================================================================
%  Load HV / CV / Time maps for the selected pair
%  ========================================================================
[hv_h, hv_b] = loadPair(infoDir, 'FinalHV',   pair.hvgsa, pair.baseline, 'prob2hv');
[cv_h, cv_b] = loadPair(infoDir, 'FinalCV',   pair.hvgsa, pair.baseline, 'prob2cv');
[t_h,  t_b ] = loadPair(infoDir, 'FinalTime', pair.hvgsa, pair.baseline, 'prob2time');

%% ========================================================================
%  Build per-problem table of paired metrics
%  ========================================================================
names    = arrayfun(@(k) sprintf('RWMOP%d', k), 1:numProblems, 'UniformOutput', false)';
dPerf    = nan(numProblems, 1);   % normalized performance improvement (HV or CV)
dPerfKind = cell(numProblems, 1);   % 'HV' or 'CV'
log10TimeRatio = nan(numProblems, 1);
log10TimeHVGSA = nan(numProblems, 1);
log10TimeBase  = nan(numProblems, 1);

for k = 1:numProblems
    name = names{k};
    if isFeasible(k)
        h = meanOverRuns(hv_h, name);
        b = meanOverRuns(hv_b, name);
        if ~isnan(h) && ~isnan(b)
            dPerf(k) = h - b;
        end
        dPerfKind{k} = 'HV';
    else
        h = meanOverRuns(cv_h, name);
        b = meanOverRuns(cv_b, name);
        if ~isnan(h) && ~isnan(b)
            denom = max([abs(h), abs(b), 1e-12]);
            dPerf(k) = (b - h) / denom;
        end
        dPerfKind{k} = 'CV';
    end

    th = meanOverRuns(t_h, name);
    tb = meanOverRuns(t_b, name);
    if ~isnan(th) && ~isnan(tb) && tb > 0 && th > 0
        log10TimeRatio(k) = log10(th / tb);
        log10TimeHVGSA(k) = log10(th);
        log10TimeBase(k)  = log10(tb);
    end
end

T = table( ...
    string(names), D_arr(:), M_arr(:), gn_arr(:), hn_arr(:), ...
    isFeasible(:), dPerf, string(dPerfKind), ...
    log10TimeRatio, log10TimeHVGSA, log10TimeBase, ...
    'VariableNames', {'name','n','m','nI','nE','feasible', ...
                      'dPerf','dPerfKind','log10TimeRatio','log10TimeHVGSA','log10TimeBase'});

csvPath = fullfile(infoDir, 'RWMOP_SensitivityTable.csv');
writetable(T, csvPath);
fprintf('Saved per-problem table -> %s\n', csvPath);

%% ========================================================================
%  Spearman correlations
%  ========================================================================
paramVals    = {T.n, T.m, T.nI, T.nE};
paramLabels  = {'$n$', '$m$', '$|\mathcal{I}|$', '$|\mathcal{E}|$'};
paramShorts  = {'n', 'm', '|I|', '|E|'};

hv_mask  = T.feasible  & ~isnan(T.dPerf);
cv_mask  = ~T.feasible & ~isnan(T.dPerf);
all_mask = ~isnan(T.log10TimeRatio);

corrHV   = nan(1, 4); pHV   = nan(1, 4);
corrCV   = nan(1, 4); pCV   = nan(1, 4);
corrTime = nan(1, 4); pTime = nan(1, 4);
for j = 1:4
    pj = paramVals{j};
    [corrHV(j),   pHV(j)]   = safeSpearman(pj(hv_mask),  T.dPerf(hv_mask));
    [corrCV(j),   pCV(j)]   = safeSpearman(pj(cv_mask),  T.dPerf(cv_mask));
    [corrTime(j), pTime(j)] = safeSpearman(pj(all_mask), T.log10TimeRatio(all_mask));
end

% Save correlation table to CSV
corrTable = table( ...
    string(paramShorts(:)), ...
    corrHV(:),   pHV(:), ...
    corrCV(:),   pCV(:), ...
    corrTime(:), pTime(:), ...
    'VariableNames', {'parameter','rho_dHV','p_dHV','rho_dCV','p_dCV','rho_logTimeRatio','p_logTimeRatio'});
corrCsvPath = fullfile(infoDir, 'RWMOP_SensitivityCorrelations.csv');
writetable(corrTable, corrCsvPath);
fprintf('Saved correlation table -> %s\n', corrCsvPath);

%% ========================================================================
%  Console summary (paragraph-ready)
%  ========================================================================
fprintf('\n====== Sensitivity Summary: %s ======\n', pair.label);
fprintf('  Spearman rho (p-value):\n');
fprintf('  %-8s | %-22s | %-22s | %-22s\n', ...
    'param', 'dHV (feasible)', 'dCV (infeasible)', 'log10(t_H/t_B) (all)');
for j = 1:4
    fprintf('  %-8s | %+5.3f (p=%6.3f)       | %+5.3f (p=%6.3f)       | %+5.3f (p=%6.3f)\n', ...
        paramShorts{j}, corrHV(j), pHV(j), corrCV(j), pCV(j), corrTime(j), pTime(j));
end
[~, idxHV]   = max(abs(corrHV));
[~, idxCV]   = max(abs(corrCV));
[~, idxTime] = max(abs(corrTime));
fprintf('  --> dominant driver of HV gain:       %s (|rho|=%.2f)\n', paramShorts{idxHV},   abs(corrHV(idxHV)));
fprintf('  --> dominant driver of CV reduction:  %s (|rho|=%.2f)\n', paramShorts{idxCV},   abs(corrCV(idxCV)));
fprintf('  --> dominant driver of time overhead: %s (|rho|=%.2f)\n', paramShorts{idxTime}, abs(corrTime(idxTime)));
fprintf('  (n_feasible=%d, n_infeasible=%d, n_all=%d)\n', sum(hv_mask), sum(cv_mask), sum(all_mask));

%% ========================================================================
%  Figure 1: 2x4 scatter grid
%  ========================================================================
fig = PreprocessProductionImage(2.0, 0.52, 1.1);
clf(fig);
tl = tiledlayout(fig, 2, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('Within-RCM Sensitivity: %s', pair.label), ...
    'Interpreter', 'latex', 'FontSize', 9);

feasColor   = [0.10 0.30 0.65];
infeasColor = [0.85 0.40 0.10];

% -- Row 1: Performance improvement --
hFeas = []; hInfeas = [];
for j = 1:4
    ax = nexttile(tl);
    hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
    pj = paramVals{j};

    hFeas = scatter(ax, pj(hv_mask), T.dPerf(hv_mask), 30, ...
        'MarkerFaceColor', feasColor, 'MarkerEdgeColor', 'k', ...
        'Marker', 'o', 'MarkerFaceAlpha', 0.75);
    hInfeas = scatter(ax, pj(cv_mask), T.dPerf(cv_mask), 34, ...
        'MarkerFaceColor', infeasColor, 'MarkerEdgeColor', 'k', ...
        'Marker', 's', 'MarkerFaceAlpha', 0.75);

    yline(ax, 0, '-', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.6, 'HandleVisibility','off');

    % Linear best-fit over the union (visual aid only)
    allValid = hv_mask | cv_mask;
    if sum(allValid) >= 3
        pp = pj(allValid); yy = T.dPerf(allValid);
        cf = polyfit(pp, yy, 1);
        xR = linspace(min(pp), max(pp), 50);
        plot(ax, xR, polyval(cf, xR), '--', 'Color', [0.4 0.4 0.4], ...
            'LineWidth', 0.8, 'HandleVisibility','off');
    end

    xlabel(ax, paramLabels{j}, 'Interpreter', 'latex', 'FontSize', 9);
    if j == 1
        ylabel(ax, {'$\Delta$ HV (feas.) /', 'norm.\ $\Delta$ CV (infeas.)'}, ...
            'Interpreter', 'latex', 'FontSize', 9);
    end
    annotateTwoRho(ax, corrHV(j), pHV(j), corrCV(j), pCV(j));
end

% -- Row 2: Time overhead --
for j = 1:4
    ax = nexttile(tl);
    hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
    pj = paramVals{j};

    scatter(ax, pj(T.feasible  & all_mask), T.log10TimeRatio(T.feasible  & all_mask), 30, ...
        'MarkerFaceColor', feasColor, 'MarkerEdgeColor', 'k', ...
        'Marker', 'o', 'MarkerFaceAlpha', 0.75, 'HandleVisibility','off');
    scatter(ax, pj(~T.feasible & all_mask), T.log10TimeRatio(~T.feasible & all_mask), 34, ...
        'MarkerFaceColor', infeasColor, 'MarkerEdgeColor', 'k', ...
        'Marker', 's', 'MarkerFaceAlpha', 0.75, 'HandleVisibility','off');

    yline(ax, 0, '-', 'Color', [0.5 0.5 0.5], 'LineWidth', 0.6, 'HandleVisibility','off');

    if sum(all_mask) >= 3
        pp = pj(all_mask); yy = T.log10TimeRatio(all_mask);
        cf = polyfit(pp, yy, 1);
        xR = linspace(min(pp), max(pp), 50);
        plot(ax, xR, polyval(cf, xR), '--', 'Color', [0.4 0.4 0.4], ...
            'LineWidth', 0.8, 'HandleVisibility','off');
    end

    xlabel(ax, paramLabels{j}, 'Interpreter', 'latex', 'FontSize', 9);
    if j == 1
        ylabel(ax, '$\log_{10}\!\left(t_{\mathrm{HVGSA}}\,/\,t_{\mathrm{base}}\right)$', ...
            'Interpreter', 'latex', 'FontSize', 9);
    end
    annotateSingleRho(ax, corrTime(j), pTime(j));
end

lg = legend([hFeas, hInfeas], ...
    {'Feasible RCM ($\Delta$ HV)', 'Infeasible RCM (norm.\ $\Delta$ CV)'}, ...
    'Interpreter', 'latex', 'FontSize', 8);
lg.Layout.Tile = 'south';
lg.NumColumns = 2;
lg.Box = 'off';

scatterPath = fullfile(visDir, 'RWMOP_Sensitivity_Scatter.pdf');
exportgraphics(fig, scatterPath, 'ContentType', 'vector');
fprintf('Saved scatter figure -> %s\n', scatterPath);

%% ========================================================================
%  Figure 2: Sensitivity-ranking bar chart
%  ========================================================================
fig2 = PreprocessProductionImage(1.0, 0.7, 1.1);
clf(fig2);
ax = axes(fig2);
hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');

barData  = [abs(corrHV); abs(corrCV); abs(corrTime)]';   % [4 x 3]
signData = [sign(corrHV); sign(corrCV); sign(corrTime)]';
pData    = [pHV; pCV; pTime]';

b = bar(ax, barData, 'grouped', 'EdgeColor', 'k', 'LineWidth', 0.6);
b(1).FaceColor = [0.30 0.55 0.85];
b(2).FaceColor = [0.85 0.55 0.35];
b(3).FaceColor = [0.45 0.75 0.50];

% Sign / significance markers above each bar
for k = 1:numel(b)
    for j = 1:4
        if isnan(barData(j, k)) || barData(j, k) < 1e-6, continue; end
        sgn = signData(j, k);
        if sgn >= 0, mk = '+'; else, mk = '$-$'; end
        if pData(j, k) < 0.05
            txt = ['\textbf{' mk '}'];
        else
            txt = mk;
        end
        text(ax, b(k).XEndPoints(j), barData(j, k) + 0.025, txt, ...
            'HorizontalAlignment', 'center', 'Interpreter', 'latex', ...
            'FontSize', 9);
    end
end

set(ax, 'XTick', 1:4, 'XTickLabel', paramLabels, ...
    'TickLabelInterpreter', 'latex', 'FontSize', 9);
ylabel(ax, '$|\rho_{\mathrm{Spearman}}|$', 'Interpreter', 'latex', 'FontSize', 10);
ylim(ax, [0, 1.05]);
title(ax, sprintf('Parameter sensitivity (%s)', pair.label), ...
    'Interpreter', 'latex', 'FontSize', 10);
legend(ax, ...
    {'$\Delta$ HV (feasible)', ...
     'norm.\ $\Delta$ CV (infeasible)', ...
     '$\log_{10}$(time ratio)'}, ...
    'Interpreter', 'latex', 'Location', 'northwest', 'FontSize', 8);

barsPath = fullfile(visDir, 'RWMOP_Sensitivity_Bars.pdf');
exportgraphics(fig2, barsPath, 'ContentType', 'vector');
fprintf('Saved bar figure     -> %s\n', barsPath);

fprintf('\n========================================\n');
fprintf('RWMOP SENSITIVITY ANALYSIS COMPLETE\n');
fprintf('========================================\n');

%% ========================================================================
%  Local helpers
%  ========================================================================
function root = resolvePlatEMORoot(scriptDir)
%RESOLVEPLATEMOROOT Locate PlatEMO root given the script directory.
%   The script lives at PlatEMO/Benchmarks/. PlatEMO root is one up.
%   If CWD is already PlatEMO (conventional pipeline run), use CWD.
    if exist(fullfile(pwd, 'Info'), 'dir') && exist(fullfile(pwd, 'Benchmarks'), 'dir')
        root = pwd;
    else
        root = fullfile(scriptDir, '..');
    end
end

function [mh, mb] = loadPair(infoDir, subdir, hvgsaName, baselineName, mapVar)
    mh = loadMap(fullfile(infoDir, subdir, hvgsaName,    [mapVar '.mat']), mapVar);
    mb = loadMap(fullfile(infoDir, subdir, baselineName, [mapVar '.mat']), mapVar);
end

function map = loadMap(filePath, mapVar)
    map = containers.Map();
    if ~exist(filePath, 'file')
        warning('RWMOPSensitivity:missing', 'Missing metric file: %s', filePath);
        return;
    end
    S = load(filePath);
    if isfield(S, mapVar) && isa(S.(mapVar), 'containers.Map')
        map = S.(mapVar);
    else
        fn = fieldnames(S);
        for i = 1:numel(fn)
            if isa(S.(fn{i}), 'containers.Map')
                map = S.(fn{i});
                return;
            end
        end
    end
end

function val = meanOverRuns(map, name)
    if isa(map, 'containers.Map') && isKey(map, name)
        v = map(name);
        v = v(~isnan(v));
        if isempty(v), val = NaN; else, val = mean(v); end
    else
        val = NaN;
    end
end

function [rho, p] = safeSpearman(x, y)
    x = x(:); y = y(:);
    valid = ~isnan(x) & ~isnan(y);
    if sum(valid) < 3
        rho = NaN; p = NaN; return;
    end
    [rho, p] = corr(x(valid), y(valid), 'Type', 'Spearman');
end

function annotateTwoRho(ax, rhoH, pH, rhoC, pC)
    lines = {};
    if ~isnan(rhoH)
        lines{end+1} = fmtRho('\rho_{\mathrm{HV}}', rhoH, pH); %#ok<AGROW>
    end
    if ~isnan(rhoC)
        lines{end+1} = fmtRho('\rho_{\mathrm{CV}}', rhoC, pC); %#ok<AGROW>
    end
    if isempty(lines), return; end
    placeCornerText(ax, lines);
end

function annotateSingleRho(ax, rho, p)
    if isnan(rho), return; end
    placeCornerText(ax, {fmtRho('\rho', rho, p)});
end

function s = fmtRho(sym, rho, p)
    if p < 0.05
        s = sprintf('$\\mathbf{%s=%+.2f}$ $(p=%.3f)$', sym, rho, p);
    else
        s = sprintf('$%s=%+.2f$ $(p=%.2f)$', sym, rho, p);
    end
end

function placeCornerText(ax, lines)
    drawnow;
    xL = xlim(ax); yL = ylim(ax);
    x = xL(1) + 0.04*(xL(2)-xL(1));
    y = yL(2) - 0.04*(yL(2)-yL(1));
    text(ax, x, y, lines, 'Interpreter', 'latex', ...
        'VerticalAlignment', 'top', 'HorizontalAlignment', 'left', ...
        'FontSize', 7.5, 'BackgroundColor', [1 1 1 0.75], ...
        'EdgeColor', [0.75 0.75 0.75], 'Margin', 1.5);
end
