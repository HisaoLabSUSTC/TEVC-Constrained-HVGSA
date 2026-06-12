% Hypervolume landscape with GSA search direction visualization
% Grid-sample pairs (t1, t2) and compute HV for each 2-solution population

n = 1000;
t1_grid = linspace(0, 1, n);
t2_grid = linspace(0, 1, n);
[T1, T2] = meshgrid(t1_grid, t2_grid);

% Objective values for solution 1 (parameterized by t1)
F1_1 = T1 + 0.25 + 0.5 * cos(4*pi*T1);
F2_1 = 1.25 - T1 + 0.5 * cos(4*pi*T1);

% Objective values for solution 2 (parameterized by t2)
F1_2 = T2 + 0.25 + 0.5 * cos(4*pi*T2);
F2_2 = 1.25 - T2 + 0.5 * cos(4*pi*T2);

% Hypervolume via inclusion-exclusion of two rectangles to ref
ref = [2, 2];
HV = max(0, ref(1)-F1_1) .* max(0, ref(2)-F2_1) + ...
     max(0, ref(1)-F1_2) .* max(0, ref(2)-F2_2) - ...
     max(0, ref(1)-max(F1_1,F1_2)) .* max(0, ref(2)-max(F2_1,F2_2));

% Create figure
PreprocessProductionImage(0.25, 1, 8.8);

% Heatmap
imagesc(t1_grid, t2_grid, HV);
axis xy; box on
hold on;

% Symmetry line (y = x)
plot([0 1], [0 1], 'k--', 'LineWidth', 2);

%% GSA computation
% Population positions in decision space
x0 = [0.33, 0.68]; % Red (iterate)
x1 = [0.33, 0.62]; % Blue (neighbor)
x2 = [0.37, 0.68]; % Blue (neighbor)

% Objective function helpers
f1_of = @(t) t + 0.25 + 0.5*cos(4*pi*t);
f2_of = @(t) 1.25 - t + 0.5*cos(4*pi*t);

% HV via inclusion-exclusion for a 2-solution population
hv_of = @(t) max(0,ref(1)-f1_of(t(1)))*max(0,ref(2)-f2_of(t(1))) + ...
             max(0,ref(1)-f1_of(t(2)))*max(0,ref(2)-f2_of(t(2))) - ...
             max(0,ref(1)-max(f1_of(t(1)),f1_of(t(2))))*max(0,ref(2)-max(f2_of(t(1)),f2_of(t(2))));

hv_x0 = hv_of(x0);
hv_x1 = hv_of(x1);
hv_x2 = hv_of(x2);

% Directional derivatives
xi = [x1; x2];         % r x d (2x2)
hv_xi = [hv_x1; hv_x2]; % r x 1
diffs = xi - x0;       % r x d
norms = vecnorm(diffs, 2, 2); % r x 1
d_vec = (hv_xi - hv_x0) ./ norms; % r x 1

% Direction matrix V (d x r)
V = (diffs ./ norms)'; % d x r (2x2)

% Normal equations: (V'V + I) lambda = d
lambda = (V'*V + eye(size(V,2))) \ d_vec;

% Search direction nu_S*
v_raw = V * lambda;
nu_star = v_raw / norm(v_raw);

%% Arrows
% Green arrow: red -> green
quiver(x0(1), x0(2), (x1(1)-x0(1))*0.8, (x1(2)-x0(2))*0.8, 0, ...
    'Color', [0.3 0.75 0.93], 'LineWidth', 3, 'MaxHeadSize', 1);

% Blue arrow: red -> blue
quiver(x0(1), x0(2), (x2(1)-x0(1))*0.8, (x2(2)-x0(2))*0.8, 0, ...
    'Color', [0.3 0.75 0.93], 'LineWidth', 3, 'MaxHeadSize', 1);

% Red arrow: GSA search direction nu_S*
arrow_len = 0.2;
quiver(x0(1), x0(2), nu_star(1)*arrow_len, nu_star(2)*arrow_len, 0, ...
    'Color', 'r', 'LineWidth', 5, 'MaxHeadSize', 1);

%% Population markers (drawn last so they appear on top)
% Red population
plot(x0(1), x0(2), 'ro', 'MarkerSize', 26, ...
    'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

% Green population
plot(x1(1), x1(2), '^', 'Color', [0.3 0.75 0.93], 'MarkerSize', 26, ...
    'MarkerFaceColor', [0.3 0.75 0.93], 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

% Blue population
plot(x2(1), x2(2), '^', 'Color', [0.3 0.75 0.93], 'MarkerSize', 26, ...
    'MarkerFaceColor', [0.3 0.75 0.93], 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

% Purple colormap (distinguishable from red/green/light blue)
% Set power < 1 to enhance dark contrast, or > 1 to enhance light contrast
power_factor = 3; % 0.5 represents a square-root curve
% Generate non-linear query points
query_points = linspace(0, 1, 256)'.^power_factor;
% Generate the colormap using the skewed points
cmap = interp1([0; 0.5; 1], [1 1 1; 0.7 0.3 0.7; 0.3 0 0.5], query_points);


colormap(cmap);
colorbar('off');

% Formatting: labels only, no title, no legend, no ticks
xlabel('$t^{(1)}$', 'Interpreter', 'latex');
ylabel('$t^{(2)}$', 'Interpreter', 'latex', 'Rotation', 0);
set(gca, 'XTick', [], 'YTick', []);
xlim([0 0.5]);
ylim([0.5 1]);
hold off;

filename = 'ProduceImage/images/HVSpaceGSA-blueNeighbor.pdf';
% exportgraphics(gcf, filename, 'Resolution', 300);
exportgraphics(gcf, filename, 'ContentType', 'vector');
close(gcf);
