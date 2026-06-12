%% ===============================================================
%  Example 4: Neighborhood-based Point Selection (Publication-Grade)
%  ---------------------------------------------------------------
%  - Clean, consistent styling matching Examples 1–3
%  - LaTeX axis labels ($x_1$, $x_2$), docking-safe axes reset
%  - Explicit handles & legend control (NaN proxy for radius circle)
%  - Professional team labels drawn on canvas (not in legend)
%  - EPS export ready for production
%  ---------------------------------------------------------------
clear; close all; clc;

%% ===================== (1) COLOR & STYLE SETTINGS =====================
%% Colors (consistent palette)
Colors.front      = [0.0, 0.0, 0.0];   % (Reserved) Black: true front (not used here)
Colors.neighbor   = [0.2, 0.6, 0.2];   % Green: neighbors (matching "final")
Colors.feasible   = [0.2, 0.4, 0.8];   % Blue: other points/background
Colors.infeasible = [0.8, 0.2, 0.2];   % Red: (reserved)
Colors.special    = [0.85, 0.10, 0.10];% Brighter red: special/team members
Colors.circle     = [0.30, 0.30, 0.30];% Gray: neighborhood circles
Colors.connection = [0.50, 0.50, 0.50];% Gray: connection lines
Colors.text       = [0.10, 0.10, 0.10];% Dark gray: text
Colors.random = [0.7412    0.5765    0.2000];

%% Alpha (transparency)
Alpha.other      = 0.70;
Alpha.neighbor   = 0.95;
Alpha.special    = 0.95;
Alpha.circle     = 0.65;
Alpha.connection = 0.50;

%% Marker sizes & widths
MarkerSize.other    = 60;
MarkerSize.neighbor = 110;
MarkerSize.special  = 130;

LineWidth.circle    = 2.0;
LineWidth.connection= 1.5;
LineWidth.marker    = 1.2;

%% ===================== (2) DATA & NEIGHBOR SELECTION =====================
%% Random points and settings (reproducible)
rng(1307296988);
numPoints   = 300;
points      = rand(numPoints, 2);
numSpecial  = 5;
specialIdx  = randperm(numPoints, numSpecial);

% Neighborhood radius
sr = 0.05;

%% Distances & nearest neighbors (within radius)
D = squareform(pdist(points));               % NxN pairwise distances

neighborMask = false(numPoints, 1);
pairs = [];                                  % rows of [special_idx, neighbor_idx]

for i = 1:numSpecial
    idx = specialIdx(i);
    d = D(idx, :);

    within = (d <= sr);
    within(idx) = false;                     % exclude self

    candIdx = find(within);
    if ~isempty(candIdx)
        [~, ord] = sort(d(candIdx), 'ascend');
        chosen = candIdx(ord(1:min(2, numel(candIdx))));
        neighborMask(chosen) = true;

        % store pairs (idx -> chosen neighbors)
        pairs = [pairs; [idx * ones(numel(chosen),1), chosen(:)]]; %#ok<AGROW>
    end
end

%% Masks
specialMask = false(numPoints, 1);
specialMask(specialIdx) = true;
otherMask = ~(specialMask | neighborMask);

%% (Optional downstream arrays kept, but silenced and supported)
specialPoints  = points(specialMask, :);   %#ok<NASGU>
neighborPoints = points(neighborMask, :);  %#ok<NASGU>

% Provide Flatten() for downstream use (row-wise concatenation)
flat_X0 = Flatten(specialPoints);           %#ok<NASGU>
if ~isempty(neighborPoints)
    team_neighbor_dist = pdist2(specialPoints, neighborPoints); %#ok<NASGU>
else
    team_neighbor_dist = [];               %#ok<NASGU>
end

% Build neighbor-arranged variants (kept for compatibility; not plotted)
neighborArr = {};
if ~isempty(neighborPoints)
    neighborArr = cell(1, size(neighborPoints,1));
    for j = 1:size(neighborPoints, 1)
        % find closest team member to neighbor j
        [~, iMin] = min(pdist2(specialPoints, neighborPoints(j,:)));
        temp = specialPoints;
        temp(iMin, :) = neighborPoints(j, :);
        neighborArr{j} = Flatten(temp);
    end
end
cell_flat_decs = cellfun(@(c) Flatten(c), neighborArr, 'UniformOutput', false); %#ok<NASGU>
if ~isempty(cell_flat_decs)
    flat_Xi = vertcat(cell_flat_decs{:});  %#ok<NASGU>
else
    flat_Xi = [];                          %#ok<NASGU>
end

%% ===================== (3) FIGURE & AXES =====================
fig = figure('Position', [100, 100, 900, 900], ...
             'Name', 'Example 4: Neighborhood-based Selection', ...
             'Color', 'w');

ax = axes('Parent', fig, 'Position', [0.10, 0.10, 0.85, 0.85]);
cla(ax, 'reset'); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); axis(ax, 'equal');

%% ===================== (4) (CONTENTS) PLOTTING =====================
%% (Contents) Background "other" points
h_other = gobjects(1,1);
if any(otherMask)
    h_other = scatter(ax, ...
        points(otherMask,1), points(otherMask,2), ...
        'SizeData', MarkerSize.other, ...
        'CData', Colors.random, ...
        'Marker', 'o', ...
        'MarkerFaceColor', 'flat', ...
        'MarkerEdgeColor', 'none', ...
        'MarkerFaceAlpha', Alpha.other, ...
        'DisplayName', 'Other Points');
end

%% (Contents) Neighborhood circles around each team member
t = linspace(0, 2*pi, 256);
for i = 1:numSpecial
    c  = points(specialIdx(i), :);
    cx = c(1) + sr*cos(t);
    cy = c(2) + sr*sin(t);
    plot(ax, cx, cy, '-', ...
        'Color', [Colors.circle, Alpha.circle], ...
        'LineWidth', LineWidth.circle, ...
        'HandleVisibility', 'off');
end

%% (Contents) Connection lines (team member → chosen neighbors)
for r = 1:size(pairs, 1)
    p1 = points(pairs(r,1), :);
    p2 = points(pairs(r,2), :);
    plot(ax, [p1(1) p2(1)], [p1(2) p2(2)], '-', ...
        'Color', [Colors.connection, Alpha.connection], ...
        'LineWidth', LineWidth.connection, ...
        'HandleVisibility', 'off');
end

%% (Contents) Neighbors within radius
h_neighbor = gobjects(1,1);
if any(neighborMask)
    h_neighbor = scatter(ax, ...
        points(neighborMask,1), points(neighborMask,2), ...
        'SizeData', MarkerSize.neighbor, ...
        'CData', Colors.neighbor, ...
        'Marker', '^', ...
        'MarkerFaceColor', 'flat', ...
        'MarkerEdgeColor', 'k', ...
        'MarkerEdgeAlpha', 0.9, ...
        'LineWidth', LineWidth.marker, ...
        'DisplayName', 'Selected Neighbors');
end

%% (Contents) Team members (special points)
h_special = gobjects(1,1);
if any(specialMask)
    h_special = scatter(ax, ...
        points(specialMask,1), points(specialMask,2), ...
        'SizeData', MarkerSize.special, ...
        'CData', Colors.special, ...
        'Marker', 's', ...
        'MarkerFaceColor', 'flat', ...
        'MarkerEdgeColor', 'k', ...
        'MarkerEdgeAlpha', 0.95, ...
        'LineWidth', LineWidth.marker, ...
        'DisplayName', 'Team Members');
end

%% (Contents) Professional team labels (on canvas only; not in legend)
% Use subtle background to ensure readability
if any(specialMask)
    TEAM_LABEL_FS = 18;
    for i = 1:numSpecial
        c = points(specialIdx(i), :);
        if i == 1
            x_offset = 0.002;
            y_offset = 0.018;
        elseif i == 3
            x_offset = -0.025;
            y_offset = 0.018;
        elseif i == 4
            x_offset = 0.015;
            y_offset = 0.018;
        else
            x_offset = -0.015;
            y_offset = 0.018;
        end
        text(ax, c(1) + x_offset, c(2) + y_offset, sprintf('%d', i), ...
                'Interpreter', 'latex', ...
                'FontWeight', 'bold', ...
                'FontSize', TEAM_LABEL_FS, ...
                'Color', Colors.text, ...
                'HorizontalAlignment', 'left', ...
                'VerticalAlignment', 'bottom', ...
                'BackgroundColor', [1 1 1 0.75], ...  % translucent white backdrop
                'Margin', 2, ...
                'Clipping', 'on');
    end
end

%% ===================== (5) LABELS, LIMITS, LEGEND =====================
%% Labels (LaTeX)
xlabel(ax, '$x_1$', 'Interpreter', 'latex');
ylabel(ax, '$x_2$', 'Interpreter', 'latex');

%% Axis limits
xlim(ax, [-0.02, 1.02]);
ylim(ax, [-0.02, 1.02]);

%% Legend (explicit handles; add NaN proxy for radius)
legend_handles = [];
legend_labels  = {};

if isgraphics(h_other)
    legend_handles(end+1) = h_other; %#ok<SAGROW>
    legend_labels{end+1}  = 'Other Points'; %#ok<SAGROW>
end

if isgraphics(h_special)
    legend_handles(end+1) = h_special; %#ok<SAGROW>
    legend_labels{end+1}  = 'Team Members'; %#ok<SAGROW>
end

if isgraphics(h_neighbor)
    legend_handles(end+1) = h_neighbor; %#ok<SAGROW>
    legend_labels{end+1}  = 'Selected Neighbors'; %#ok<SAGROW>
end

% Representative circle proxy (for legend text & style)
h_circle_proxy = plot(ax, nan, nan, '-', ...
    'Color', [Colors.circle, Alpha.circle], ...
    'LineWidth', LineWidth.circle, ...
    'DisplayName', sprintf('Radius $r = %.2f$', sr));
legend_handles(end+1) = h_circle_proxy; %#ok<SAGROW>
legend_labels{end+1}  = sprintf('Radius $r = %.2f$', sr); %#ok<SAGROW>



legend(ax, legend_handles, legend_labels, ...
    'Interpreter', 'latex', ...
    'Location', 'best');

%% Title
% title(ax, sprintf('Neighborhood-based Selection with $r=%.2f$', sr), ...
%     'Interpreter', 'latex', ...
%     'FontSize', 22, 'FontWeight', 'bold');

%% Final font & EPS export
set(ax, 'FontSize', 24, 'FontName', 'Times');
if exist('EnlargeFont', 'file'); EnlargeFont(); end
print('./Visualization/images/Example4.eps','-depsc');

hold(ax, 'off');

%% ===================== (6) HELPERS =====================
function out = Flatten(M)
% Flatten an N-by-2 matrix into a 1-by-(2N) row vector [x1 y1 x2 y2 ...]
    if isempty(M)
        out = [];
        return;
    end
    out = reshape(M.', 1, []); % transpose first to interleave x,y pairs row-wise
end
