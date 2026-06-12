function selected_indices = SelectByRBDN(Population, U)
    if rand() < 0.8
        % Always include extreme solutions (usually 2-3 for 2D)
        extreme_indices = findExtremeSolutions(Population.objs);
        n_extreme = min(length(extreme_indices), floor(U/2));
        
        % Remaining slots use rotating selection
        remaining_U = U - n_extreme;
        other_indices = setdiff(1:length(Population), extreme_indices);
        
        % Check if we have enough other solutions
        if isempty(other_indices) || remaining_U <= 0
            % Just return the extreme solutions or random selection
            if n_extreme >= U
                selected_indices = extreme_indices(1:U)';
            else
                selected_indices = randperm(numel(Population), U);
            end
            return;
        end
        
        other_pops = Population(other_indices);
        other_objs = other_pops.objs;
    
        [N, M] = size(other_objs);
        
        % Ensure we have valid k for k-NN distance
        k = max(1, floor(sqrt(N)));  % Ensure k is at least 1
        
        Distance = pdist2(other_objs, other_objs);
        Distance(logical(eye(length(Distance)))) = inf;
        Distance = sort(Distance,2);
    
        % Check if we have enough columns
        if size(Distance, 2) >= k
            D = 1./(Distance(:,k)+2);
        else
            % Fallback: use the last available column
            D = 1./(Distance(:,end)+2);
        end
        
        [~, sorted_idx] = sort(D, 'descend');
    
        % Ensure we don't select more than available
        actual_selected = min(remaining_U, length(sorted_idx));
        relative_indices = sorted_idx(1:actual_selected)';
    
        % Combine selections
        selected_indices = [extreme_indices(1:n_extreme)', other_indices(relative_indices)];
    else
        selected_indices = randperm(numel(Population), U);
    end
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