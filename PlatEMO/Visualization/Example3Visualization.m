%% ===============================================================
%  Example 3: Subset-only Expansion on a 2D Linear Pareto Front
%  -------------------------------------------------------------
%  Production-grade visuals to match Example 1 & 2
%  - LaTeX labels ($f_1$, $f_2$)
%  - Structured blocks (%% Colors / %% Contents / %% Legend)
%  - Explicit handles, name-value pairs, and EPS export
%  - Gradient movement paths (red → green) for moved subset
%  - Legends omit non-existent groups (no "Previous Points" in Fig 1 & 4)
%  -------------------------------------------------------------
clear; close all; clc;

%% ===================== (1) COLOR & STYLE SETTINGS =====================
%% Colors (consistent palette)
Colors.front      = [0.0, 0.0, 0.0];      % Black: true Pareto front
Colors.neighbor   = [0.65, 0.65, 0.65];   % Gray: background/unused
Colors.feasible   = [0.2, 0.4, 0.8];      % Blue: feasible/current points
Colors.infeasible = [0.8, 0.2, 0.2];      % Red: previous points (pre-move)
Colors.final      = [0.2, 0.6, 0.2];      % Green: expanded subset (highlight)
Colors.arrow      = [0.9, 0.3, 0.3];      % Red base for generic movement (fallback)
Colors.ref        = [0.0, 0.0, 0.0];      % Dark green: reference point

%% Alpha (transparency)
Alpha.prev  = 1;   % keep previous points visible & crisp
Alpha.curr  = 1;   % current points
Alpha.arrow = 1.00;   % path segments

%% Marker sizes
MarkerSize.prev     = 140;
MarkerSize.curr     = 140;
MarkerSize.expanded = 140;
MarkerSize.ref      = 140;

%% ===================== (2) PROBLEM SETUP =====================
mu = 5;
t0 = linspace(0.1, 0.9, mu);           % Parameter along the front
P0 = [t0(:), 1 - t0(:)];               % Initial points on PF (minimization)
ref = [1.1, 1.1];                      % Reference point (≥ all coords)

% Movement configuration
targets = [0.2, 0.8; 0.5, 0.5; 0.8, 0.2];
S_left  = [1 2 3];
S_right = [3 4 5];

% Two-iteration movement
P1 = move_towards_targets(P0, S_left,  targets, 0.5);      % Iteration 1
P2 = move_towards_targets_flip(P1, S_right, targets, 0.5); % Iteration 2

% Hypervolumes (2D minimization)
hv0 = hv2d_min(P0, ref);
hv1 = hv2d_min(P1, ref);
hv2 = hv2d_min(P2, ref);

% Figure layout
fig_width  = 700; 
fig_height = 680;
x_offset   = 100; 
y_position = 300;

%% ===================== (3) FIGURE 1: INITIAL =====================
fig1 = figure('Position', [x_offset, y_position, fig_width, fig_height], ...
              'Name', 'Example 3-1: Initial Population', ...
              'Color', 'w');
ax1 = axes('Parent', fig1, 'Position', [0.1, 0.1, 0.85, 0.85]);

%% (Contents) Initial state (no previous points / no paths)
plotScene(ax1, ...
    P0, ...                   % P (current)
    [], ...                   % P_prev (none)
    [], ...                   % S (none)
    ref, Colors, Alpha, MarkerSize, ...
    'Initial Population', ... % expand_label
    'showPrev', false, ...    % do not plot prev group
    'legendMode', 'initial', ... % legend excludes prev/path
    'drawGradient', false);   % no movement in fig 1

%% Labels (LaTeX)
xlabel(ax1, '$f_1$', 'Interpreter', 'latex');
ylabel(ax1, '$f_2$', 'Interpreter', 'latex');

%% Title
title(ax1, sprintf('Iteration 0: 5-optimal (HV = %.4f)', hv0), ...
      'FontSize', 18, 'FontWeight', 'bold');

%% Formatting & Export
set(ax1, 'FontSize', 24, 'FontName', 'Times');
if exist('EnlargeFont', 'file'); EnlargeFont(); end
print('./Visualization/images/Example3_1.eps','-depsc');

%% ===================== (4) FIGURE 2: ITERATION 1 =====================
fig2 = figure('Position', [x_offset + fig_width + 50, y_position, fig_width, fig_height], ...
              'Name', 'Example 3-2: Iteration 1', ...
              'Color', 'w');
ax2 = axes('Parent', fig2, 'Position', [0.1, 0.1, 0.85, 0.85]);

%% (Contents) Iteration 1 (with previous points + gradient paths for subset)
plotScene(ax2, ...
    P1, ...                   % P (current)
    P0, ...                   % P_prev
    S_left, ...               % S (subset moved)
    ref, Colors, Alpha, MarkerSize, ...
    'Moving Points (Post-GSA)', ...
    'showPrev', true, ...
    'legendMode', 'full', ...     % include prev & path in legend
    'drawGradient', true);        % draw gradient (red→green) paths

%% Labels (LaTeX)
xlabel(ax2, '$f_1$', 'Interpreter', 'latex');
ylabel(ax2, '$f_2$', 'Interpreter', 'latex');

%% Title
title(ax2, sprintf('Iteration 1: Move [%s] (HV = %.4f)', num2str(S_left), hv1), ...
      'FontSize', 18, 'FontWeight', 'bold');

%% Formatting & Export
set(ax2, 'FontSize', 24, 'FontName', 'Times');
if exist('EnlargeFont', 'file'); EnlargeFont(); end
print('./Visualization/images/Example3_2.eps','-depsc');

%% ===================== (5) FIGURE 3: ITERATION 2 =====================
fig3 = figure('Position', [x_offset + 2*(fig_width + 50), y_position, fig_width, fig_height], ...
              'Name', 'Example 3-3: Iteration 2', ...
              'Color', 'w');
ax3 = axes('Parent', fig3, 'Position', [0.1, 0.1, 0.85, 0.85]);

%% (Contents) Iteration 2 (with previous points + gradient paths for subset)
plotScene(ax3, ...
    P2, ...                   % P (current)
    P1, ...                   % P_prev
    S_right, ...              % S (subset moved)
    ref, Colors, Alpha, MarkerSize, ...
    'Moving Points (Post-GSA)', ...
    'showPrev', true, ...
    'legendMode', 'full', ...
    'drawGradient', true);

%% Labels (LaTeX)
xlabel(ax3, '$f_1$', 'Interpreter', 'latex');
ylabel(ax3, '$f_2$', 'Interpreter', 'latex');

%% Title
title(ax3, sprintf('Iteration 2: Move [%s] (HV = %.4f)', num2str(S_right), hv2), ...
      'FontSize', 18, 'FontWeight', 'bold');

%% Formatting & Export
set(ax3, 'FontSize', 24, 'FontName', 'Times');
if exist('EnlargeFont', 'file'); EnlargeFont(); end
print('./Visualization/images/Example3_3.eps','-depsc');

%% ===================== (6) FIGURE 4: FINAL =====================
fig4 = figure('Position', [x_offset, y_position, fig_width, fig_height], ...
              'Name', 'Example 3-4: Final Population', ...
              'Color', 'w');
ax4 = axes('Parent', fig4, 'Position', [0.1, 0.1, 0.85, 0.85]);

%% (Contents) Final state (no previous points / no paths)
plotScene(ax4, ...
    P2, ...                   % P (current/final)
    [], ...                   % P_prev (none)
    [], ...                   % S (none)
    ref, Colors, Alpha, MarkerSize, ...
    'Final Population', ...
    'showPrev', false, ...
    'legendMode', 'final', ...    % legend excludes prev/path
    'drawGradient', false);       % no movement in fig 4

%% Labels (LaTeX)
xlabel(ax4, '$f_1$', 'Interpreter', 'latex');
ylabel(ax4, '$f_2$', 'Interpreter', 'latex');

%% Title
title(ax4, sprintf('Iteration 2: after GSA (HV = %.4f)', hv2), ...
      'FontSize', 18, 'FontWeight', 'bold');

%% Formatting & Export
set(ax4, 'FontSize', 24, 'FontName', 'Times');
if exist('EnlargeFont', 'file'); EnlargeFont(); end
print('./Visualization/images/Example3_4.eps','-depsc');

%% ===============================================================
%                        SUPPORTING FUNCTIONS
%% ===============================================================

function plotScene(ax, P, P_prev, S, ref, Colors, Alpha, MarkerSize, expand_label, varargin)
% Clean, consistent plotting function with block decorations and legend control.
% Name-value pairs:
%   'showPrev'    : true/false – plot previous points
%   'legendMode'  : 'initial' | 'full' | 'final'
%   'drawGradient': true/false – draw red→green gradient paths (for indices in S)

    %% -------- Parse inputs --------
    p = inputParser;
    addParameter(p, 'showPrev', true, @(x)islogical(x));
    addParameter(p, 'legendMode', 'full', @(s)ischar(s) || isstring(s));
    addParameter(p, 'drawGradient', false, @(x)islogical(x));
    parse(p, varargin{:});
    showPrev     = p.Results.showPrev;
    legendMode   = char(p.Results.legendMode);
    drawGradient = p.Results.drawGradient;

    %% ========== (A) Axes Reset & Scaffolding ==========
    cla(ax, 'reset');
    hold(ax, 'on');
    grid(ax, 'on');
    box(ax, 'on');
    axis(ax, 'equal');

    %% ========== (B) True Pareto Front ==========
    xx = linspace(0, 1, 200);
    yy = 1 - xx;
    h_front = plot(ax, xx, yy, '-', ...
        'Color', Colors.front, ...
        'LineWidth', 2, ...
        'DisplayName', 'True Pareto Front');

    %% ========== (C) Reference Point ==========
    h_ref = scatter(ax, ...
        ref(1), ref(2), ...
        'SizeData', MarkerSize.ref, ...
        'CData', Colors.ref, ...
        'Marker', 's', ...
        'MarkerFaceColor', 'flat', ...
        'MarkerEdgeColor', 'none', ...
        'DisplayName', 'Reference Point');

    %% ========== (D) Previous Points (if any) ==========
    h_prev = gobjects(1,1);
    if showPrev && ~isempty(P_prev)
        h_prev = scatter(ax, ...
            P_prev(:,1), P_prev(:,2), ...
            'SizeData', MarkerSize.prev, ...
            'CData', Colors.infeasible, ...
            'Marker', 'o', ...
            'MarkerFaceColor', 'flat', ...
            'MarkerEdgeColor', 'none', ...
            'MarkerFaceAlpha', Alpha.prev, ...
            'DisplayName', 'Moving Points (Pre-GSA)');
    end

    %% ========== (E) Movement Paths (red → green gradient) ==========
    % Draw for the moved subset S only
    if drawGradient && ~isempty(P_prev) && ~isempty(S)
        nSeg = 36;  % granularity of gradient
        for i = 1:numel(S)
            idx = S(i);
            p0 = P_prev(idx, :);
            p1 = P(idx, :);
            drawGradientPath(ax, p0, p1, Colors.infeasible, Colors.final, nSeg, Alpha.arrow, 5.0);
        end
        % Legend proxy for movement path (single-color representation)
        h_path_leg = plot(ax, NaN, NaN, '-', ...
            'Color', Colors.arrow, ...
            'LineWidth', 3, ...
            'DisplayName', 'GSA Trajectories');
    else
        h_path_leg = gobjects(1,1);
    end

    %% ========== (F) Current Points ==========
    CP = setdiff(P, P(S,:), 'rows');
    h_curr = scatter(ax, ...
        CP(:,1), CP(:,2), ...
        'SizeData', MarkerSize.curr, ...
        'CData', Colors.feasible, ...
        'Marker', 'o', ...
        'MarkerFaceColor', 'flat', ...
        'MarkerEdgeColor', 'none', ...
        'MarkerFaceAlpha', Alpha.curr, ...
        'DisplayName', 'Stationary Points');

    %% ========== (G) Expanded Subset Highlight (if any) ==========
    h_exp = gobjects(1,1);
    if ~isempty(S)
        h_exp = scatter(ax, ...
            P(S,1), P(S,2), ...
            'SizeData', MarkerSize.expanded, ...
            'CData', Colors.final, ...
            'Marker', '^', ...
            'MarkerFaceColor', 'flat', ...
            'MarkerEdgeColor', 'none', ...
            'LineWidth', 2, ...
            'DisplayName', expand_label);
    end

    %% ========== (H) Labels & Limits ==========
    xlabel(ax, '$f_1$', 'Interpreter', 'latex');
    ylabel(ax, '$f_2$', 'Interpreter', 'latex');
    xlim(ax, [-0.05, 1.15]);
    ylim(ax, [-0.05, 1.15]);

    %% ========== (I) Legend (assemble per mode) ==========
    switch lower(legendMode)
        case 'initial'
            % No previous points / no path
            legend(ax, [h_front, h_ref, h_curr], ...
                'Interpreter', 'latex', 'Location', 'best');
        case 'final'
            % No previous points / no path; include final highlight if present
            if isgraphics(h_exp)
                legend(ax, [h_front, h_ref, h_curr, h_exp], ...
                    'Interpreter', 'latex', 'Location', 'best');
            else
                legend(ax, [h_front, h_ref, h_curr], ...
                    'Interpreter', 'latex', 'Location', 'best');
            end
        otherwise % 'full'
            % Include previous, movement path legend proxy, current, expanded
            handles = [h_front, h_ref];
            handles(end+1) = h_curr;
            if isgraphics(h_prev);     handles(end+1) = h_prev; end %#ok<AGROW>
            if isgraphics(h_exp);      handles(end+1) = h_exp; end %#ok<AGROW>
            if isgraphics(h_path_leg); handles(end+1) = h_path_leg; end %#ok<AGROW>
            legend(ax, handles, 'Interpreter', 'latex', 'Location', 'best');
    end

    %% ========== (J) Stacking (front beneath everything else) ==========
    uistack(h_front, 'bottom'); % keep the PF line at the back

    %% ========== (K) Final Font ==========
    set(ax, 'FontSize', 24, 'FontName', 'Times');
end

function drawGradientPath(ax, p0, p1, colorStart, colorEnd, nSeg, alpha, lineWidth)
% Draw a segmented line from p0 -> p1 with a color gradient (start→end).
% Uses short line segments for EPS-friendly gradient approximation.

    % Parameterization
    t = linspace(0, 1, nSeg+1);
    x = (1 - t) * p0(1) + t * p1(1);
    y = (1 - t) * p0(2) + t * p1(2);

    % Segment-by-segment drawing with interpolated colors
    for k = 1:nSeg
        % endpoints of segment k
        xs = x(k:k+1);
        ys = y(k:k+1);

        % color at segment midpoint
        tm = (t(k) + t(k+1)) / 2;
        c  = (1 - tm) * colorStart + tm * colorEnd;

        line(ax, xs, ys, ...
            'LineStyle', '-', ...
            'LineWidth', lineWidth, ...
            'Color', [c, alpha], ...
            'HandleVisibility', 'off');
    end
end

function P_new = move_towards_targets(P, S, targets, alpha)
% Move selected indices S from their current positions toward targets
% alpha in [0,1]: fraction toward target.
    P_new = P;
    for i = 1:length(S)
        idx = S(i);
        if idx <= 3
            target_idx = idx;
        else
            target_idx = idx - 2;
        end
        target_idx = min(target_idx, size(targets, 1));
        current = P(idx, :);
        target  = targets(target_idx, :);
        P_new(idx, :) = current + alpha * (target - current);
    end
end

function P_new = move_towards_targets_flip(P, S, targets, alpha)
% Alternate mapping for the second iteration.
    P_new = P;
    for i = 1:length(S)
        idx = S(i);
        if idx >= 3
            target_idx = idx - 2;
        else
            target_idx = idx;
        end
        target_idx = min(target_idx, size(targets, 1));
        current = P(idx, :);
        target  = targets(target_idx, :);
        P_new(idx, :) = current + alpha * (target - current);
    end
end

function hv = hv2d_min(P, ref)
% Hypervolume (Lebesgue measure) for 2D minimization sets w.r.t. reference.
% Assumes P is a matrix of size [N x 2]. Returns scalar HV.
    if isempty(P); hv = 0; return; end
    [x, idx] = sort(P(:,1), 'ascend');
    y = P(idx, 2);
    y = cummin(y);               % ensure monotonic w.r.t. dominance
    hv = 0;
    y_prev = ref(2);
    for i = 1:numel(x)
        dy = max(0, y_prev - y(i));
        hv = hv + max(0, ref(1) - x(i)) * dy;
        y_prev = min(y_prev, y(i));
    end
end
