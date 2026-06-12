% Define the decision variable t with high resolution for a smooth curve
t = linspace(0, 1, 1001);
l = linspace(-1, 4, 1001);
% Define the two objective functions
f1 = t + 0.25 + 0.5 * cos(4 * pi * t);
f2 = 1.25 - t + 0.5 * cos(4 * pi * t);

g1 = l;
g2 = 0.7-(l);
% g2 = 0.7-(l*1.5);
% Create the figure
PreprocessProductionImage(0.25, 1, 8.8)
plot(f1, f2, 'k-', 'LineWidth', 3);
hold on;
plot(g1, g2, 'k-', 'LineWidth', 3);


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

% Gradient infeasible region (below constraint line f1 + f2 = 0.7)
% Perpendicular distance from line: d = (0.7 - f1 - f2) / sqrt(2)
n_img = 1000;
x_img = linspace(-0.25, 2.25, n_img);
y_img = linspace(-0.25, 2.25, n_img);
[X_img, Y_img] = meshgrid(x_img, y_img);
perp_dist = max(0, (0.7 - X_img - Y_img) / sqrt(2));
norm_d = perp_dist / max(perp_dist(:));
% Light gray (0.8) at boundary -> black (0) at max distance
gray_level = 0.8 * (1 - norm_d);
infeas_rgb = cat(3, gray_level, gray_level, gray_level);
infeas_alpha = double(perp_dist > 0);
h_infeas = imagesc(x_img, y_img, infeas_rgb);
set(h_infeas, 'AlphaData', infeas_alpha);

% Check feasibility: a point is feasible when f1 + f2 >= 0.7
feas1 = (f1_pop1 + f2_pop1) >= 0.7;
feas2 = (f1_pop2 + f2_pop2) >= 0.7;
feas3 = (f1_pop3 + f2_pop3) >= 0.7;

% Build hypervolume polyshapes only for feasible points
hv_red = polyshape();
for i = find(feas1)
    hv_red = union(hv_red, ...
        polyshape([f1_pop1(i) f1_pop1(i) ref(1) ref(1)], ...
                  [f2_pop1(i) ref(2) ref(2) f2_pop1(i)]));
end
hv_green = polyshape();
for i = find(feas2)
    hv_green = union(hv_green, ...
        polyshape([f1_pop2(i) f1_pop2(i) ref(1) ref(1)], ...
                  [f2_pop2(i) ref(2) ref(2) f2_pop2(i)]));
end
hv_blue = polyshape();
for i = find(feas3)
    hv_blue = union(hv_blue, ...
        polyshape([f1_pop3(i) f1_pop3(i) ref(1) ref(1)], ...
                  [f2_pop3(i) ref(2) ref(2) f2_pop3(i)]));
end

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



filename = 'ProduceImage/images/ConstrainedObjectiveSpace.png';
exportgraphics(gcf, filename, 'Resolution', 300);
close(gcf);
