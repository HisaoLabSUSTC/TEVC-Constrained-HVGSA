function selected_indices = SelectByBoundaryBias(Population, U)
    % Prioritize extreme solutions in each objective
    
    objs = Population.objs;
    [n, m] = size(objs);
    
    % Find extreme solutions
    boundary_indices = [];
    for i = 1:m
        [~, min_idx] = min(objs(:, i));
        [~, max_idx] = max(objs(:, i));
        boundary_indices = unique([boundary_indices; min_idx; max_idx]);
    end
    
    % If we need more solutions, add neighbors
    if length(boundary_indices) < U
        % Find neighbors of boundary solutions
        selected = false(n, 1);
        selected(boundary_indices) = true;
        
        while sum(selected) < U
            % Add solutions closest to current selection
            distances = inf(n, 1);
            for i = 1:n
                if ~selected(i)
                    dist_to_selected = min(pdist2(objs(i, :), objs(selected, :)));
                    distances(i) = dist_to_selected;
                end
            end
            
            [~, next_idx] = min(distances);
            selected(next_idx) = true;
        end
        
        selected_indices = find(selected);
    else
        selected_indices = boundary_indices(1:U);
    end
    selected_indices = selected_indices';
end