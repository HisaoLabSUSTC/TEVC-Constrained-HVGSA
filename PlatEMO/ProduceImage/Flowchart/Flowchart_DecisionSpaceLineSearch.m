% Flowchart_DecisionSpaceLineSearch.m
% Decision space for Red population with line search step sizes.
% The original population appears as small light markers, and three trial
% populations (alpha = 0.32, 0.2, 0.11) appear as progressively larger and
% darker markers along the t-axis.

PreprocessProductionImage(0.25, 0.3, 8.8);

% Draw the t-axis line
plot([0 1], [0 0], 'k-', 'LineWidth', 3);
hold on;

%% Original red population in decision space
t_orig = [0.33, 0.68];

%% HVGSA direction in concatenated decision space
d = [-0.65, 0.8];

%% Line search: three step sizes
alphas = [0.32, 0.2, 0.11];
n_steps = length(alphas);

% Compute populations for each step size
t_steps = cell(1, n_steps);
for k = 1:n_steps
    t_steps{k} = t_orig + alphas(k) * d;
end

%% Population markers (drawn last so they appear on top)
% Shades from light (original) to dark (most refined step)
colors = [1.00 0.55 0.55;   % original   — light red
          0.95 0.35 0.35;   % alpha=0.32 — medium-light
          0.75 0.15 0.15;   % alpha=0.2  — medium-dark
          0.50 0.00 0.00];  % alpha=0.11 — dark red
sizes = [14, 18, 24, 30];

% Original (smallest, lightest)
plot(t_orig, zeros(size(t_orig)), 'o', 'Color', colors(1,:), ...
    'MarkerSize', sizes(1), 'MarkerFaceColor', colors(1,:), 'LineWidth', 1.5);

% Three step populations (progressively larger and darker)
for k = 1:n_steps
    plot(t_steps{k}, zeros(size(t_steps{k})), 'o', 'Color', colors(k+1,:), ...
        'MarkerSize', sizes(k+1), 'MarkerFaceColor', colors(k+1,:), 'LineWidth', 1.5);
end

%% Formatting: labels only, no title, no legend, no ticks
xlabel('$t$', 'Interpreter', 'latex', 'rotation', 270);
set(gca, 'XTick', [], 'YTick', [], 'YColor', 'none');
xlim([-0.05 1.05]);
ylim([-0.5 0.5]);
hold off;

filename = 'ProduceImage/images/DecisionSpaceLineSearch.png';
exportgraphics(gcf, filename, 'Resolution', 300);
close(gcf);
