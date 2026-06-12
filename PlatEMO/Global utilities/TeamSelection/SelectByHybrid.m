function selected_indices = SelectByHybrid(Population, U, Z, iteration)
    % Combine multiple heuristics
    
    % Always include extreme solutions (usually 2-3 for 2D)
    extreme_indices = findExtremeSolutions(Population.objs);
    n_extreme = min(length(extreme_indices), floor(U/2));
    
    % Remaining slots use rotating selection
    remaining_U = U - n_extreme;
    other_indices = setdiff(1:length(Population), extreme_indices);
    
    % Apply rotating sector to non-extreme solutions
    Pop_subset = Population(other_indices);
    relative_selected = SelectByRefVecRegions(Pop_subset, remaining_U, Z, iteration);
    
    % Combine selections
    selected_indices = [extreme_indices(1:n_extreme)', other_indices(relative_selected)];
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