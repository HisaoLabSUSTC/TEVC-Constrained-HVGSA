function VisualizeExample2(Problem)
    % Initialize problem and population
    Population = Problem.Initialization();
    
    if ishandle(1) && strcmp(get(1, 'Type'), 'figure')
        disp('Figure 1 exists.');
        fig1 = figure(1);
    else
        disp('Figure 1 does not exist.');
        fig1 = figure('Position', [100, 100, 1200, 900], ...
                     'Name', 'Objective Space with original non-dominance');
    end

    if ishandle(2) && strcmp(get(2, 'Type'), 'figure')
        disp('Figure 2 exists.');
        fig2 = figure(2);
    else
        disp('Figure 2 does not exist.');
        fig2 = figure('Position', [110, 90, 1200, 900], ...
                         'Name', 'Objective Space with alternative non-dominance');
    end
    
    figure(fig1);
    ax1 = axes('Position', [0.1, 0.1, 0.85, 0.85]);
    
    % Create figure
    figure(fig2);
    ax2 = axes('Position', [0.1, 0.1, 0.85, 0.85]);

    plotSparse2D(ax1, ax2, Population, Problem);

    figure(fig1);
    % EnlargeFont();
    print('./Visualization/images/Example2Original.eps','-depsc')

    figure(fig2);
    % EnlargeFont();
    print('./Visualization/images/Example2Expanded.eps','-depsc')
end

function plotSparse2D(ax1, ax2, Population, Problem)
    %% ax1
    cla(ax1, 'reset');
    hold(ax1, 'on');
    grid(ax1, 'on');
    
    %% Labels
    xlabel(ax1, '$f_1$', 'Interpreter', 'latex');
    ylabel(ax1, '$f_2$', 'Interpreter', 'latex');

    %% Titles
    % No Title
    
    %% Colors
    neighbor_color = [0.7412    0.5765    0.2000];
    feasible_color = [0.2, 0.8, 0.2];
    infeasible_color = [0.8, 0.2, 0.2];
    nd_color = [0.2, 0.2, 1];
    final_color = [0.2, 0.6, 0.2];
    traj_color = [0.9, 0.3, 0.3];

    %% (Contents) Feasible points
    objs = Population.objs; cons = Population.cons; feasible = all(cons <= 0, 2);
    feas_pops = Population(feasible); infeas_pops = Population(~feasible);
    min_radius = 0.2; feas_sparse = []; 
    [feas_sparse, feas_idx] = sparseSample2D(feas_pops, min_radius);
   
    h_feas = scatter(ax1, ...
        feas_sparse(:,1), feas_sparse(:,2), ...
        'SizeData', 140, ...
        'CData', feasible_color, ...
        'Marker', 'o', ...
        'MarkerFaceColor', 'flat', ...
        'MarkerEdgeColor', 'none', ...
        'LineWidth', 1);
    
    infeas_sparse = [];
    [infeas_sparse, infeas_idx] = sparseSample2D(infeas_pops, min_radius);
    
    h_infeas = scatter(ax1, ...
        infeas_sparse(:,1), infeas_sparse(:,2), ...
        'SizeData', 140, ...
        'CData', infeasible_color, ...
        'Marker', 'o', ...
        'MarkerFaceColor', 'flat', ...
        'MarkerEdgeColor', 'none', ...
        'LineWidth', 1);

    feas_idx = find(feas_idx); infeas_idx = find(infeas_idx);
    SampledPop = [feas_pops(feas_idx), infeas_pops(infeas_idx)];
    [FrontNo,~] = NDSort(SampledPop.objs, SampledPop.cons, 1);
    NDFront = SampledPop(FrontNo==1); nd_objs = NDFront.objs;
        
    h_nd = scatter(ax1, ...
        nd_objs(:,1), nd_objs(:,2), ...
        'SizeData', 120, ...
        'MarkerFaceColor', 'none', ...              % hollow
        'MarkerEdgeColor', nd_color, ...         % blue outline
        'LineWidth', 3, ...
        'DisplayName', 'Nondominated Solutions');

   % Add legend
    legend(ax1, [h_feas, h_infeas, h_nd], ...
        {'Feasible Solutions', ...
        'Infeasible Solutions', ...
        'Nondominated Solutions'}, 'interpreter', 'latex');
    legend(ax1, 'Location', 'best');
    set(ax1, 'FontSize', 24, 'FontName', 'Times');


    %% ax2
    cla(ax2, 'reset');
    hold(ax2, 'on');
    grid(ax2, 'on');

    %% Labels (No title)
    xlabel(ax2, '$f_1$', 'Interpreter', 'latex');
    ylabel(ax2, '$f_2$', 'Interpreter', 'latex');
    % title(ax2, 'Objective Space', ...
    %       'FontSize', 14, 'FontWeight', 'bold');


    sampled_feas_pop = feas_pops(feas_idx); sampled_infeas_pop = infeas_pops(infeas_idx);
    [~,ExPop,dominated_idx,dominator_idx] = VisualizeNondominance(NDFront, SampledPop);
    DominatedPop = SampledPop(dominated_idx); DominatorPop = SampledPop(dominator_idx);

    sampled_objs = SampledPop.objs; dominated_objs = DominatedPop.objs;
    dominator_objs = DominatorPop.objs; ex_objs = ExPop.objs;

    sampled_objs = setdiff(sampled_objs, [dominated_objs;dominator_objs], 'rows');
    h_leftover = scatter(ax2, ...
        sampled_objs(:,1), sampled_objs(:,2), ...
        'SizeData', 120, ...
        'MarkerFaceColor', 'flat', ...
        'CData', infeasible_color, ...
        'MarkerEdgeColor', 'none'); % Leftover solutions

    h_dominated = scatter(ax2, ...
        dominated_objs(:,1), dominated_objs(:,2), ...
        'SizeData', 120, ...
        'CData', neighbor_color, ...
        'MarkerFaceColor', 'Flat', ...
        'Marker', 'x', ...
        'MarkerEdgeColor', neighbor_color, ...
        'LineWidth', 2); % Dominated solutions

    h_leg_dominated = plot(ax2, NaN, NaN, ...
        'Marker', 'x', ...
        'Color', neighbor_color, ...
        'LineWidth', 1.5, ...
        'MarkerSize', 10, ...
        'LineStyle', 'none');

    h_dominator = scatter(ax2, ...
        dominator_objs(:,1), dominator_objs(:,2), ...
        'SizeData', 120, ...
        'CData', neighbor_color, ...
        'MarkerFaceColor', 'Flat', ...
        'Marker', '*', ...
        'MarkerEdgeColor', neighbor_color, ...
        'LineWidth', 2); % Dominator solutions

    h_leg_dominator = plot(ax2, NaN, NaN, ...
        'Marker', '*', ...
        'Color', neighbor_color, ...
        'LineWidth', 1.5, ...
        'MarkerSize', 10, ...
        'LineStyle', 'none');

    h_og = scatter(ax2, ...
        nd_objs(:,1), nd_objs(:,2), ...
        'SizeData', 140, ...
        'CData', feasible_color, ...
        'Marker', 'o', ...
        'MarkerFaceColor', 'flat', ...
        'MarkerEdgeColor', 'none', ...
        'LineWidth', 1);

    h_exp = scatter(ax2, ...
        ex_objs(:,1), ex_objs(:,2), ...
        'SizeData', 120, ...
        'MarkerFaceColor', 'none', ...              % hollow
        'MarkerEdgeColor', nd_color, ...         % blue outline
        'LineWidth', 3, ...
        'DisplayName', 'Nondominated Solutions');


        
    % Add legend
    legend(ax2, [h_leg_dominated, h_leg_dominator, h_leftover, h_og, h_exp], ...
        {'Dominated Solutions', ...
        'Dominating Solutions', ...
        'Remaining Solutions', ...
        'Original ND Front', ...
        'Expanded ND Front'}, 'interpreter', 'latex');
    legend(ax2, 'Location', 'best');
    set(ax2, 'FontSize', 24, 'FontName', 'Times');


end

function [sparse_points, idx] = sparseSample2D(pop, min_radius)
    % Greedy algorithm for sparse sampling in 2D
    % Ensures no two selected points are closer than min_radius
    
    if isempty(pop)
        sparse_points = [];
        idx = [];
        return;
    end

    points = pop.objs;
    
    % Normalize points for better radius calculation
    ranges = max(points) - min(points);
    ranges(ranges == 0) = 1; % Avoid division by zero
    norm_radius = min_radius ./ ranges;
    norm_points = (points - min(points)) ./ ranges;
    
    % Initialize with random first point
    n = size(norm_points, 1);
    selected = false(n, 1);
    indices = randperm(n);
    selected(indices(1)) = true;
    
    % Greedy selection
    for i = 2:n
        candidate_idx = indices(i);
        candidate = norm_points(candidate_idx, :);
        
        % Check distance to all selected points
        selected_points = norm_points(selected, :);
        distances = sqrt(sum((selected_points - candidate).^2, 2));
        
        % Add if far enough from all selected points
        if all(distances >= norm_radius(1))
            selected(candidate_idx) = true;
            
            % Optional: stop if we have enough points
            if sum(selected) >= 50  % Maximum 50 points for clarity
                break;
            end
        end
    end
    
    sparse_points = points(selected, :);
    idx = selected;
end

function [indices, ExPop, dominated_idx, dominator_idx] = VisualizeNondominance(FixPop, Pop)

    FixObjs = FixPop.objs;
    PopObjs = Pop.objs;
    [DiffObjs, iDiff] = setdiff(PopObjs, FixObjs, "rows");

    FixBlock = permute(FixObjs, [3 2 1]);

    DiffPop = Pop(iDiff);

    dominated = any(all(DiffObjs > FixBlock(:,:,:), 2), 3);
    dominator = any(all(DiffObjs < FixBlock(:,:,:), 2), 3);

    dominated_idx = iDiff(dominated);
    dominator_idx = iDiff(dominator);
    
    keep_idx = find(~(dominated | dominator));

    kept_pop = DiffPop(keep_idx);

    [FrontNo,~] = NDSort(kept_pop.objs, 1);
    ND_idx = find(FrontNo==1);

    indices = keep_idx(ND_idx);
    kept_pop = DiffPop(keep_idx);
    ExPop = [kept_pop(ND_idx), FixPop];
end



