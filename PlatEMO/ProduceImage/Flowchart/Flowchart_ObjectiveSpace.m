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

% Compute population objective values
t_pop1 = [0.33, 0.68];
f1_pop1 = t_pop1 + 0.25 + 0.5 * cos(4 * pi * t_pop1);
f2_pop1 = 1.25 - t_pop1 + 0.5 * cos(4 * pi * t_pop1);

t_pop2 = [0.22, 0.71];
f1_pop2 = t_pop2 + 0.25 + 0.5 * cos(4 * pi * t_pop2);
f2_pop2 = 1.25 - t_pop2 + 0.5 * cos(4 * pi * t_pop2);

t_pop3 = [0.37, 0.62];
f1_pop3 = t_pop3 + 0.25 + 0.5 * cos(4 * pi * t_pop3);
f2_pop3 = 1.25 - t_pop3 + 0.5 * cos(4 * pi * t_pop3);

% Build hypervolume polyshapes (union of two rectangles per population)
hv_red = union( ...
    polyshape([f1_pop1(1) f1_pop1(1) ref(1) ref(1)], [f2_pop1(1) ref(2) ref(2) f2_pop1(1)]), ...
    polyshape([f1_pop1(2) f1_pop1(2) ref(1) ref(1)], [f2_pop1(2) ref(2) ref(2) f2_pop1(2)]));
hv_green = union( ...
    polyshape([f1_pop2(1) f1_pop2(1) ref(1) ref(1)], [f2_pop2(1) ref(2) ref(2) f2_pop2(1)]), ...
    polyshape([f1_pop2(2) f1_pop2(2) ref(1) ref(1)], [f2_pop2(2) ref(2) ref(2) f2_pop2(2)]));
hv_blue = union( ...
    polyshape([f1_pop3(1) f1_pop3(1) ref(1) ref(1)], [f2_pop3(1) ref(2) ref(2) f2_pop3(1)]), ...
    polyshape([f1_pop3(2) f1_pop3(2) ref(1) ref(1)], [f2_pop3(2) ref(2) ref(2) f2_pop3(2)]));

% Exclusive regions (blue on top, red middle, green bottom — no overlap)
excl_blue = hv_blue;
excl_red = subtract(hv_red, hv_blue);
excl_green = subtract(subtract(hv_green, hv_red), hv_blue);

% Draw non-overlapping hypervolume regions
plot(excl_green, 'FaceColor', [0 0.8 0], 'FaceAlpha', 0.25, 'EdgeColor', 'none');
plot(excl_red, 'FaceColor', [1 0 0], 'FaceAlpha', 0.25, 'EdgeColor', 'none');
plot(excl_blue, 'FaceColor', [0.3 0.75 0.93], 'FaceAlpha', 0.25, 'EdgeColor', 'none');

% Population markers (drawn last so they appear on top)
% Population 1: Red Circles
plot(f1_pop1, f2_pop1, 'ro', 'MarkerSize', 30, 'MarkerFaceColor', 'r', 'LineWidth', 1.5);
% Population 2: Green Squares
plot(f1_pop2, f2_pop2, 'gs', 'MarkerSize', 30, 'MarkerFaceColor', 'g', 'LineWidth', 1.5);
% Population 3: LightBlue Triangles
plot(f1_pop3, f2_pop3, '^', 'Color', [0.3 0.75 0.93], 'MarkerSize', 30, ...
    'MarkerFaceColor', [0.3 0.75 0.93], 'LineWidth', 1.5);
% Reference point: Black star
plot(ref(1), ref(2), 'p', 'Color', 'k', 'MarkerSize', 24, ...
    'MarkerFaceColor', 'k', 'LineWidth', 1.5);

% Formatting: labels only, no title, no legend, no ticks
xlabel('$f_1$', 'Interpreter', 'latex');
ylabel('$f_2$', 'Interpreter', 'latex', 'Rotation', 0);
set(gca, 'XTick', [], 'YTick', []);
grid on;
axis equal;
xlim([-0.25 2.25]);
ylim([-0.25 2.25]);
hold off;

% filename = 'ProduceImage/images/ObjectiveSpace.png';
% exportgraphics(gcf, filename, 'Resolution', 300);
% close(gcf);
