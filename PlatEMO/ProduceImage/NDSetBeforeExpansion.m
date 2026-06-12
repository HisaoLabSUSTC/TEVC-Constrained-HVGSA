% Objective-space visualization of the nondominated set BEFORE expansion.
% Draws sparse feasible/infeasible samples and the induced ND front.

rng(2048);
Problem = CF2('N', 10100);
Population = Problem.Initialization();

%% Colors
feasible_color   = [0.2 0.8 0.2];
infeasible_color = [0.8 0.2 0.2];
nd_color         = [0.2 0.2 1.0];

%% Split and sparsely sample feasible / infeasible populations
cons      = Population.cons;
feasible  = all(cons <= 0, 2);
feas_pop  = Population(feasible);
infeas_pop = Population(~feasible);
min_radius = 0.2;

[feas_sparse,   feas_mask]   = sparseSample2D(feas_pop,   min_radius);
[infeas_sparse, infeas_mask] = sparseSample2D(infeas_pop, min_radius);

SampledPop  = [feas_pop(feas_mask), infeas_pop(infeas_mask)];
[FrontNo,~] = NDSort(SampledPop.objs, SampledPop.cons, 1);
nd_objs     = SampledPop(FrontNo==1).objs;

%% Figure
PreprocessProductionImage(0.33, 1, 8.8);
hold on; grid on; box on;

scatter(feas_sparse(:,1), feas_sparse(:,2), ...
    'SizeData', 240, ...
    'CData', feasible_color, ...
    'Marker', 'o', ...
    'MarkerFaceColor', 'flat', ...
    'MarkerEdgeColor', 'none');

scatter(infeas_sparse(:,1), infeas_sparse(:,2), ...
    'SizeData', 240, ...
    'CData', infeasible_color, ...
    'Marker', 'o', ...
    'MarkerFaceColor', 'flat', ...
    'MarkerEdgeColor', 'none');

scatter(nd_objs(:,1), nd_objs(:,2), ...
    'SizeData', 260, ...
    'MarkerFaceColor', 'none', ...
    'Marker', 's', ...
    'MarkerEdgeColor', nd_color, ...
    'LineWidth', 5);

% Dummy handles for a compact legend with controlled marker sizes
h_leg_feas = plot(nan, nan, ...
    'Marker', 'o', 'LineStyle', 'none', ...
    'MarkerSize', 10, ...
    'MarkerFaceColor', feasible_color, ...
    'MarkerEdgeColor', 'none');

h_leg_infeas = plot(nan, nan, ...
    'Marker', 'o', 'LineStyle', 'none', ...
    'MarkerSize', 10, ...
    'MarkerFaceColor', infeasible_color, ...
    'MarkerEdgeColor', 'none');

h_leg_nd = plot(nan, nan, ...
    'Marker', 's', 'LineStyle', 'none', ...
    'MarkerSize', 10, ...
    'MarkerFaceColor', 'none', ...
    'MarkerEdgeColor', nd_color, ...
    'LineWidth', 3);

xlabel('$f_1$', 'Interpreter', 'latex');
ylabel('$f_2$', 'Interpreter', 'latex');

legend([h_leg_feas, h_leg_infeas, h_leg_nd], ...
    {'Feasible', 'Infeasible', '$\mathcal{F}_1$'}, ...
    'Interpreter', 'latex', 'Location', 'northeast');

hold off;

imgDir = './ProduceImage/images';
if ~exist(imgDir, 'dir'), mkdir(imgDir); end
filename = fullfile(imgDir, 'NDSetBeforeExpansion.pdf');
exportgraphics(gcf, filename, 'ContentType', 'vector');
close(gcf);


%% Local functions
function [sparse_points, selected] = sparseSample2D(pop, min_radius)
    if isempty(pop)
        sparse_points = [];
        selected      = [];
        return;
    end
    points      = pop.objs;
    ranges      = max(points) - min(points);
    ranges(ranges == 0) = 1;
    norm_radius = min_radius ./ ranges;
    norm_points = (points - min(points)) ./ ranges;
    n           = size(norm_points, 1);
    selected    = false(n, 1);
    indices     = randperm(n);
    selected(indices(1)) = true;
    for i = 2:n
        candidate_idx = indices(i);
        candidate     = norm_points(candidate_idx, :);
        sel_points    = norm_points(selected, :);
        distances     = sqrt(sum((sel_points - candidate).^2, 2));
        if all(distances >= norm_radius(1))
            selected(candidate_idx) = true;
            if sum(selected) >= 50, break; end
        end
    end
    sparse_points = points(selected, :);
end
