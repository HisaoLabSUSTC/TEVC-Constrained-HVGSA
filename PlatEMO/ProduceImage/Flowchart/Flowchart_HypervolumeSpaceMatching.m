% Hypervolume landscape over the decision variable space
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
axis xy;
hold on;

% Symmetry line (y = x)
plot([0 1], [0 1], 'k--', 'LineWidth', 2);

% Plot populations
% Red population: t = [0.33, 0.68]
plot([0.33], [0.68], 'ro', 'MarkerSize', 20, ...
    'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

% Green population: t = [0.22, 0.71]
plot([0.22], [0.71], 'gs', 'MarkerSize', 20, ...
    'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

% Blue population: t = [0.54, 0.92]
plot([0.37], [0.62], '^', 'Color', [0.3 0.75 0.93], 'MarkerSize', 20, ...
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
xlim([0 1]);
ylim([0 1]);
hold off;

filename = 'ProduceImage/images/HVSpaceMatch.png';
exportgraphics(gcf, filename, 'Resolution', 300);
close(gcf);
