% Objective-space visualization of the nondominated set AFTER expansion.
% Shows dominated / dominating neighbors relative to the original ND front,
% remaining leftover samples, and the expanded ND front.

rng(2048);
Problem = CF2('N', 10100);
Population = Problem.Initialization();

%% Colors
neighbor_color   = [0.7412 0.5765 0.2000];
feasible_color   = [0.2 0.8 0.2];
infeasible_color = [0.8 0.2 0.2];
nd_color         = [0.2 0.2 1.0];

%% Split and sparsely sample feasible / infeasible populations
cons      = Population.cons;
feasible  = all(cons <= 0, 2);
feas_pop  = Population(feasible);
infeas_pop = Population(~feasible);
min_radius = 0.2;

[~, feas_mask]   = sparseSample2D(feas_pop,   min_radius);
[~, infeas_mask] = sparseSample2D(infeas_pop, min_radius);

SampledPop  = [feas_pop(feas_mask), infeas_pop(infeas_mask)];
[FrontNo,~] = NDSort(SampledPop.objs, SampledPop.cons, 1);
NDFront     = SampledPop(FrontNo==1);
nd_objs     = NDFront.objs;

%% Expansion: classify remaining samples w.r.t. the original ND front
[~, ExPop, dominated_idx, dominator_idx] = VisualizeNondominance(NDFront, SampledPop);
DominatedPop = SampledPop(dominated_idx);
DominatorPop = SampledPop(dominator_idx);

sampled_objs   = SampledPop.objs;
dominated_objs = DominatedPop.objs;
dominator_objs = DominatorPop.objs;
ex_objs        = ExPop.objs;

leftover_objs  = setdiff(sampled_objs, [dominated_objs; dominator_objs], 'rows');

%% Figure
PreprocessProductionImage(0.33, 1, 8.8);
hold on; grid on; box on;

scatter(leftover_objs(:,1), leftover_objs(:,2), ...
    'SizeData', 240, ...
    'CData', infeasible_color, ...
    'Marker', 'o', ...
    'MarkerFaceColor', 'flat', ...
    'MarkerEdgeColor', 'none');

scatter(dominated_objs(:,1), dominated_objs(:,2), ...
    'SizeData', 240, ...
    'CData', neighbor_color, ...
    'MarkerFaceColor', 'flat', ...
    'Marker', 'x', ...
    'MarkerEdgeColor', neighbor_color, ...
    'LineWidth', 3);

scatter(dominator_objs(:,1), dominator_objs(:,2), ...
    'SizeData', 240, ...
    'CData', neighbor_color, ...
    'MarkerFaceColor', 'flat', ...
    'Marker', 'x', ...
    'MarkerEdgeColor', neighbor_color, ...
    'LineWidth', 3);

scatter(nd_objs(:,1), nd_objs(:,2), ...
    'SizeData', 240, ...
    'CData', feasible_color, ...
    'Marker', 'o', ...
    'MarkerFaceColor', 'flat', ...
    'MarkerEdgeColor', 'none');

scatter(ex_objs(:,1), ex_objs(:,2), ...
    'SizeData', 260, ...
    'MarkerFaceColor', 'none', ...
    'Marker', 's', ...
    'MarkerEdgeColor', nd_color, ...
    'LineWidth', 5);

% Dummy handles for a compact legend with controlled marker sizes
h_leg_dominated = plot(nan, nan, ...
    'Marker', 'x', 'LineStyle', 'none', ...
    'MarkerSize', 10, ...
    'Color', neighbor_color, ...
    'LineWidth', 2);

% h_leg_dominator = plot(nan, nan, ...
%     'Marker', '*', 'LineStyle', 'none', ...
%     'MarkerSize', 10, ...
%     'Color', neighbor_color, ...
%     'LineWidth', 2);

h_leg_leftover = plot(nan, nan, ...
    'Marker', 'o', 'LineStyle', 'none', ...
    'MarkerSize', 10, ...
    'MarkerFaceColor', infeasible_color, ...
    'MarkerEdgeColor', 'none');

h_leg_og = plot(nan, nan, ...
    'Marker', 'o', 'LineStyle', 'none', ...
    'MarkerSize', 10, ...
    'MarkerFaceColor', feasible_color, ...
    'MarkerEdgeColor', 'none');

h_leg_exp = plot(nan, nan, ...
    'Marker', 's', 'LineStyle', 'none', ...
    'MarkerSize', 10, ...
    'MarkerFaceColor', 'none', ...
    'MarkerEdgeColor', nd_color, ...
    'LineWidth', 3);


xlabel('$f_1$', 'Interpreter', 'latex');
ylabel('$f_2$', 'Interpreter', 'latex');

legend([h_leg_dominated, h_leg_leftover, h_leg_og, h_leg_exp], ...
    {'Eliminated', 'Infeasible', 'Feasible', '$\tilde{\mathcal{F}}_1$'}, ...
    'Interpreter', 'latex', 'Location', 'northeast');

hold off;

% imgDir = './ProduceImage/images';
% if ~exist(imgDir, 'dir'), mkdir(imgDir); end
% filename = fullfile(imgDir, 'NDSetAfterExpansion.pdf');
% exportgraphics(gcf, filename, 'ContentType', 'vector');
% close(gcf);


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

function [indices, ExPop, dominated_idx, dominator_idx] = VisualizeNondominance(FixPop, Pop)
    FixObjs = FixPop.objs;
    PopObjs = Pop.objs;
    [DiffObjs, iDiff] = setdiff(PopObjs, FixObjs, 'rows');

    FixBlock = permute(FixObjs, [3 2 1]);
    DiffPop  = Pop(iDiff);

    dominated = any(all(DiffObjs > FixBlock(:,:,:), 2), 3);
    dominator = any(all(DiffObjs < FixBlock(:,:,:), 2), 3);

    dominated_idx = iDiff(dominated);
    dominator_idx = iDiff(dominator);

    keep_idx = find(~(dominated | dominator));
    kept_pop = DiffPop(keep_idx);

    [FrontNo,~] = NDSort(kept_pop.objs, 1);
    ND_idx      = find(FrontNo==1);

    indices = keep_idx(ND_idx);
    ExPop   = [kept_pop(ND_idx), FixPop];
end
