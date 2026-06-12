function selected_indices = SelectByBoundDescDensity(Population, U)
    % Combine multiple heuristics
    
    % Always include extreme solutions (usually 2-3 for 2D)
    extreme_indices = findExtremeSolutions(Population.objs);
    n_extreme = min(length(extreme_indices), floor(U/2));
    
    % Remaining slots use rotating selection
    remaining_U = U - n_extreme;
    other_indices = setdiff(1:length(Population), extreme_indices);
    
    % Random others
    % relative_selected = randperm(numel(other_indices), remaining_U);
    
    other_pops = Population(other_indices);
    other_objs = other_pops.objs;

    [N, M] = size(other_objs);

    Distance = pdist2(other_objs, other_objs);
    Distance(logical(eye(length(Distance)))) = inf;
    Distance = sort(Distance,2);

    D = 1./(Distance(:,floor(sqrt(N)))+2);
    [~, sorted_idx] = sort(D, 'descend');

    relative_indices = sorted_idx(1:remaining_U)';

    % Combine selections
    selected_indices = [extreme_indices(1:n_extreme)', other_indices(relative_indices)];
end


function [boundary_indices] = findExtremeSolutions(objs)
    m = size(objs, 2);
    boundary_indices = [];
    for i = 1:m
        [~, min_idx] = min(objs(:, i));
        [~, max_idx] = max(objs(:, i));
        boundary_indices = unique([boundary_indices; min_idx; max_idx]);
    end
end