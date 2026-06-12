function selected_indices = SelectByRefVecHV(Population, U, Z, iteration, ref_point)
    % Advanced selection combining reference vectors and HV contribution
    
    objs = Population.objs;
    [n, m] = size(objs);
    
    % Get reference vector associations
    objs_norm = normalizeObjectives(objs);
    [associations, distances] = associateWithReferenceVectors(objs_norm, Z);
    
    % Calculate hypervolume contributions per reference vector
    vector_contributions = zeros(size(Z, 1), 1);
    vector_solutions = cell(size(Z, 1), 1);
    
    for v = 1:size(Z, 1)
        associated = find(associations == v);
        if ~isempty(associated)
            vector_solutions{v} = associated;
            
            % Calculate total HV contribution of this vector's solutions
            objs_subset = objs(associated, :);
            if size(objs_subset, 1) > 0
                hv_with = stk_dominatedhv(objs_subset, ref_point);
                vector_contributions(v) = hv_with;
            end
        end
    end
    
    % Strategy: Select from high-contribution vectors
    % but rotate to ensure coverage
    [sorted_contrib, sorted_vectors] = sort(vector_contributions, 'descend');
    
    % Remove vectors with no solutions
    valid_vectors = sorted_vectors(sorted_contrib > 0);
    
    if isempty(valid_vectors)
        % Fallback to random selection
        selected_indices = randperm(n, min(U, n))';
        return;
    end
    
    % Rotate starting point based on iteration
    start_idx = mod(iteration - 1, length(valid_vectors)) + 1;
    rotated_vectors = [valid_vectors(start_idx:end); valid_vectors(1:start_idx-1)];
    
    % Select solutions
    selected_indices = [];
    solutions_per_vector = ceil(U / min(U, length(valid_vectors)));
    
    for i = 1:length(rotated_vectors)
        v = rotated_vectors(i);
        candidates = vector_solutions{v};
        
        if ~isempty(candidates)
            % Within each vector, prioritize boundary solutions
            objs_candidates = objs(candidates, :);
            boundary_score = computeBoundaryScore(objs_candidates);
            [~, sorted_idx] = sort(boundary_score, 'descend');
            
            n_select = min(solutions_per_vector, length(candidates));
            selected_indices = [selected_indices; candidates(sorted_idx(1:n_select))];
            
            if length(selected_indices) >= U
                break;
            end
        end
    end
    
    % Trim to exactly U
    if length(selected_indices) > U
        selected_indices = selected_indices(1:U);
    end
    selected_indices = selected_indices';
end

function score = computeBoundaryScore(objs)
    % Score solutions based on how extreme they are
    
    [n, m] = size(objs);
    score = zeros(n, 1);
    
    % For each objective, check if solution is near extreme
    for i = 1:m
        sorted_vals = sort(objs(:, i));
        min_val = sorted_vals(1);
        max_val = sorted_vals(end);
        range = max_val - min_val;
        
        % Score based on proximity to extremes
        for j = 1:n
            dist_to_min = abs(objs(j, i) - min_val) / (range + eps);
            dist_to_max = abs(objs(j, i) - max_val) / (range + eps);
            
            % Higher score for solutions closer to extremes
            score(j) = score(j) + exp(-5 * min(dist_to_min, dist_to_max));
        end
    end
end

function objs_norm = normalizeObjectives(objs)
    % NSGA-III style normalization with extreme points
    
    [n, m] = size(objs);
    
    % Find ideal point
    zmin = min(objs, [], 1);
    
    % Translate objectives
    objs_translated = objs - repmat(zmin, n, 1);
    
    % Find extreme points
    extreme_indices = zeros(1, m);
    w = eye(m) + 1e-6;
    
    for i = 1:m
        [~, extreme_indices(i)] = min(max(objs_translated ./ repmat(w(i,:), n, 1), [], 2));
    end
    
    % Calculate intercepts
    try
        hyperplane = objs_translated(extreme_indices, :) \ ones(m, 1);
        a = 1 ./ hyperplane;
        if any(isnan(a) | isinf(a) | a <= 0)
            error('Invalid intercepts');
        end
    catch
        % Fallback to max values
        a = max(objs_translated, [], 1)' + 1e-6;
    end
    
    % Normalize
    objs_norm = objs_translated ./ repmat(a', n, 1);
end


function [associations, distances] = associateWithReferenceVectors(objs_norm, Z)
    % Associate each solution with its closest reference vector
    
    n = size(objs_norm, 1);
    nz = size(Z, 1);
    
    % Calculate perpendicular distances
    % Using cosine similarity approach like NSGA-III
    cosine = 1 - pdist2(objs_norm, Z, 'cosine');
    cosine = max(cosine, 0); % Handle numerical issues
    
    % Perpendicular distance from each solution to each reference line
    obj_norms = sqrt(sum(objs_norm.^2, 2));
    distances_matrix = repmat(obj_norms, 1, nz) .* sqrt(1 - cosine.^2);
    
    % Find closest reference vector for each solution
    [distances, associations] = min(distances_matrix, [], 2);
end