% Constrained Hypervolume landscape over the decision variable space
% Grid-sample pairs (t1, t2) and compute constrained HV for each 2-solution population
% Infeasible solutions (f1 + f2 < 0.7) contribute nothing to the hypervolume

n = 1000;
t1_grid = linspace(0, 1, n);
t2_grid = linspace(0, 1, n);
[T1, T2] = meshgrid(t1_grid, t2_grid);

% Reference point
ref = [2, 2];

% Objective values for solution 1 (parameterized by t1)
F1_1 = T1 + 0.25 + 0.5 * cos(4*pi*T1);
F2_1 = 1.25 - T1 + 0.5 * cos(4*pi*T1);

% Objective values for solution 2 (parameterized by t2)
F1_2 = T2 + 0.25 + 0.5 * cos(4*pi*T2);
F2_2 = 1.25 - T2 + 0.5 * cos(4*pi*T2);

% Feasibility: a solution is feasible when f1 + f2 >= 0.7
% Note: f1(t)+f2(t) = 1.5 + cos(4*pi*t), so infeasible when cos(4*pi*t) < -0.8
feas1 = (F1_1 + F2_1) >= 0.7;
feas2 = (F1_2 + F2_2) >= 0.7;

% Individual rectangle areas and overlap
area1 = max(0, ref(1)-F1_1) .* max(0, ref(2)-F2_1);
area2 = max(0, ref(1)-F1_2) .* max(0, ref(2)-F2_2);
overlap = max(0, ref(1)-max(F1_1,F1_2)) .* max(0, ref(2)-max(F2_1,F2_2));

% Constrained HV: infeasible solutions contribute nothing
% Both feasible  -> inclusion-exclusion of two rectangles
% One feasible   -> single rectangle from the feasible solution
% Neither feasible -> 0
HV = feas1 .* feas2 .* (area1 + area2 - overlap) + ...
     feas1 .* ~feas2 .* area1 + ...
     ~feas1 .* feas2 .* area2;

% Create figure
PreprocessProductionImage(0.25, 1, 8.8);

% Heatmap
imagesc(t1_grid, t2_grid, HV);
axis xy;
hold on;

% Infeasible region overlay based on total constraint violation
% CV(t) = max(0, 0.7 - f1(t) - f2(t))
cv1 = max(0, 0.7 - (F1_1 + F2_1));
cv2 = max(0, 0.7 - (F1_2 + F2_2));
total_cv = cv1 + cv2;
norm_cv = total_cv / max(total_cv(:));
% Black overlay with alpha proportional to normalized CV
% Single bands (one infeasible): low alpha -> purple heatmap blends through (purple-gray)
% Intersections (both infeasible): high alpha -> near-black
black_img = zeros(n, n, 3);
h_infeas = imagesc(t1_grid, t2_grid, black_img);
set(h_infeas, 'AlphaData', norm_cv.*(1));
% set(h_infeas, 'AlphaData', norm_cv.*0);

% Symmetry line (y = x)
plot([0 0.96], [0 0.96], 'k--', 'LineWidth', 2);

% Plot populations and their reflections
% Red population: t = [0.33, 0.68]
plot([0.33 0.68], [0.68 0.33], 'ro', 'MarkerSize', 26, ...
    'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

% Green population: t = [0.22, 0.71]
plot([0.22 0.71], [0.71 0.22], 'gs', 'MarkerSize', 26, ...
    'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

% Blue population: t = [0.37, 0.62]
plot([0.37 0.62], [0.62 0.37], '^', 'Color', [0.3 0.75 0.93], 'MarkerSize', 26, ...
    'MarkerFaceColor', [0.3 0.75 0.93], 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

% Purple colormap (same as unconstrained version)
power_factor = 3;
query_points = linspace(0, 1, 256)'.^power_factor;
cmap = interp1([0; 0.5; 1], [1 1 1; 0.7 0.3 0.7; 0.3 0 0.5], query_points);

% cmap

colormap(cmap);
colorbar('off');

% Formatting: labels only, no title, no legend, no ticks
xlabel('$t^{(1)}$', 'Interpreter', 'latex');
ylabel('$t^{(2)}$', 'Interpreter', 'latex', 'Rotation', 0);
set(gca, 'XTick', [], 'YTick', []);
xlim([0 1]);
ylim([0 1]);
hold off;


filename = 'ProduceImage/images/ConstrainedHVSpace.png';
exportgraphics(gcf, filename, 'Resolution', 300);
close(gcf);