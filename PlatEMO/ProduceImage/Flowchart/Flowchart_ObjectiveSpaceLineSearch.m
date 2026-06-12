% Flowchart_ObjectiveSpaceLineSearch.m
% Shows the HVGSA direction in objective space with line search step sizes.
% Only the red population remains. The original appears as a small marker,
% and three trial populations (alpha = 0.2, 0.1, 0.05) appear as gradually
% larger markers, moving in direction d = [-0.6, 0.8] in concatenated
% decision space.

% Define the decision variable t with high resolution for a smooth curve
t = linspace(0, 1, 1001);

% Define the two objective functions
f1 = t + 0.25 + 0.5 * cos(4 * pi * t);
f2 = 1.25 - t + 0.5 * cos(4 * pi * t);

% Create the figure
PreprocessProductionImage(0.25, 1, 8.8)
plot(f1, f2, 'k-', 'LineWidth', 3);
hold on;

%% Pareto set is [0.25, 0.75]
% Reference point
ref = [2, 2];

%% Original red population in decision space
t_orig = [0.33, 0.68];
f1_orig = t_orig + 0.25 + 0.5 * cos(4 * pi * t_orig);
f2_orig = 1.25 - t_orig + 0.5 * cos(4 * pi * t_orig);

%% HVGSA direction in concatenated decision space
d = [-0.65, 0.8];

%% Line search: three step sizes
% alphas = [0.2, 0.1, 0.05];
% alphas = [0.11]
alphas = [0.32, 0.2, 0.11];
n_steps = length(alphas);

% Compute populations for each step size
t_steps  = cell(1, n_steps);
f1_steps = cell(1, n_steps);
f2_steps = cell(1, n_steps);
for k = 1:n_steps
    t_steps{k}  = t_orig + alphas(k) * d;
    f1_steps{k} = t_steps{k} + 0.25 + 0.5 * cos(4 * pi * t_steps{k});
    f2_steps{k} = 1.25 - t_steps{k} + 0.5 * cos(4 * pi * t_steps{k});
end

%% Build hypervolume polyshapes
make_hv = @(fx, fy) union( ...
    polyshape([fx(1) fx(1) ref(1) ref(1)], [fy(1) ref(2) ref(2) fy(1)]), ...
    polyshape([fx(2) fx(2) ref(1) ref(1)], [fy(2) ref(2) ref(2) fy(2)]));

hv_orig  = make_hv(f1_orig, f2_orig);
hv_steps = cell(1, n_steps);
hv_areas = zeros(1, n_steps);
for k = 1:n_steps
    hv_steps{k} = make_hv(f1_steps{k}, f2_steps{k});
    hv_areas(k) = area(hv_steps{k});
end
[~, best] = max(hv_areas);

% HV gain: best step minus original
hv_gain = subtract(hv_steps{best}, hv_orig);

%% Draw hypervolume regions
% plot(hv_orig, 'FaceColor', [1 0.7 0.7], 'FaceAlpha', 0.25, 'EdgeColor', 'none');
% plot(hv_gain, 'FaceColor', [1 0 0],     'FaceAlpha', 0.25, 'EdgeColor', 'none');

%% Draw direction arrows (from original toward largest step, showing HVGSA direction)
% for i = 1:2
%     quiver(f1_orig(i), f2_orig(i), ...
%         f1_steps{1}(i) - f1_orig(i), f2_steps{1}(i) - f2_orig(i), 0, ...
%         'Color', [0.4 0.4 0.4], 'LineWidth', 2, 'MaxHeadSize', 0.5, ...
%         'LineStyle', '--');
% end

%% Population markers (drawn last so they appear on top)
% Shades from light (original) to dark (most refined step)
colors = [1.00 0.55 0.55;   % original   — light red
          0.95 0.35 0.35;   % alpha=0.2  — medium-light
          0.75 0.15 0.15;   % alpha=0.1  — medium-dark
          0.50 0.00 0.00];  % alpha=0.05 — dark red
sizes = [14, 18, 24, 30];

% Original (smallest, lightest)
plot(f1_orig, f2_orig, 'o', 'Color', colors(1,:), 'MarkerSize', sizes(1), ...
    'MarkerFaceColor', colors(1,:), 'LineWidth', 1.5);

% Three step populations (progressively larger and darker)
for k = 1:n_steps
    plot(f1_steps{k}, f2_steps{k}, 'o', 'Color', colors(k+1,:), ...
        'MarkerSize', sizes(k+1), 'MarkerFaceColor', colors(k+1,:), 'LineWidth', 1.5);
end

% Reference point: Black star
plot(ref(1), ref(2), 'p', 'Color', 'k', 'MarkerSize', 24, ...
    'MarkerFaceColor', 'k', 'LineWidth', 1.5);

%% Formatting: labels only, no title, no legend, no ticks
xlabel('$f_1$', 'Interpreter', 'latex');
ylabel('$f_2$', 'Interpreter', 'latex', 'Rotation', 0);
set(gca, 'XTick', [], 'YTick', []);
grid on;
axis equal;
xlim([-0.25 2.25]);
ylim([-0.25 2.25]);
hold off;

% filename = 'ProduceImage/images/ObjectiveSpaceLineSearch.png';
% exportgraphics(gcf, filename, 'Resolution', 300);
% close(gcf);
