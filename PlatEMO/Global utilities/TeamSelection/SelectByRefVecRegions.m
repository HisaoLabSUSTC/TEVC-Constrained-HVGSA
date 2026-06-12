function selected_indices = SelectByRefVecRegions(Population, U, Z, iteration)
    % Select solutions based on reference vector associations
    % Similar to NSGA-III but for subset selection
    % Z: reference vectors (same as NSGA-III uses)
    
    objs = Population.objs;
    [n, m] = size(objs);
    nz = size(Z, 1);
    
    % Normalize objectives (adaptive normalization like NSGA-III)
    objs_norm = normalizeObjectives(objs);
    
    % Associate each solution with reference vectors
    [associations, distances] = associateWithReferenceVectors(objs_norm, Z);
    
    % Strategy 1: Rotating through reference vectors
    % This ensures all regions get attention over iterations
    vectors_per_iter = min(U, nz);
    start_vector = mod((iteration-1) * vectors_per_iter, nz) + 1;
    
    if start_vector + vectors_per_iter - 1 <= nz
        active_vectors = start_vector:(start_vector + vectors_per_iter - 1);
    else
        % Wrap around
        active_vectors = [start_vector:nz, 1:(vectors_per_iter - (nz - start_vector + 1))];
    end
    
    % Select solutions associated with active reference vectors
    selected_indices = [];
    
    for v = active_vectors
        % Find solutions associated with this vector
        associated = find(associations == v);
        
        if ~isempty(associated)
            % Sort by distance to reference vector
            [~, sorted_idx] = sort(distances(associated));
            
            % Take the closest one (or more if needed)
            n_from_this_vector = ceil(U / length(active_vectors));
            n_select = min(n_from_this_vector, length(associated));
            
            selected_indices = [selected_indices; associated(sorted_idx(1:n_select))];
        end
    end
    
    % If we don't have enough, add based on contribution
    if length(selected_indices) < U
        remaining = setdiff(1:n, selected_indices);
        n_needed = U - length(selected_indices);
        
        % Select from remaining based on sparsity
        if ~isempty(remaining)
            % Choose from least crowded regions (but only those with actual solutions)
            crowd_count = zeros(nz, 1);
            for v = 1:nz
                crowd_count(v) = sum(associations == v);
            end
            
            % Find vectors that have at least one solution from remaining
            remaining_associations = associations(remaining);
            vectors_with_remaining = unique(remaining_associations);
            
            if ~isempty(vectors_with_remaining)
                % Among vectors with remaining solutions, find least crowded
                crowd_subset = crowd_count(vectors_with_remaining);
                [~, idx] = sort(crowd_subset);
                sorted_vectors = vectors_with_remaining(idx);
                
                candidates = [];
                for i = 1:length(sorted_vectors)
                    v = sorted_vectors(i);
                    % Find remaining solutions associated with this vector
                    v_candidates = remaining(remaining_associations == v);
                    
                    if ~isempty(v_candidates)
                        candidates = [candidates; v_candidates(:)];
                        
                        % Stop if we have enough candidates
                        if length(candidates) >= n_needed
                            break;
                        end
                    end
                end
                
                % Select needed number from candidates
                if length(candidates) >= n_needed
                    selected_indices = [selected_indices; candidates(1:n_needed)];
                else
                    selected_indices = [selected_indices; candidates];
                    
                    % If still need more, select randomly from what's left
                    rest = setdiff(remaining, candidates);
                    n_still_needed = U - length(selected_indices);
                    if n_still_needed > 0 && ~isempty(rest)
                        random_idx = randperm(length(rest), min(n_still_needed, length(rest)));
                        selected_indices = [selected_indices; rest(random_idx)'];
                    end
                end
            else
                % No remaining solutions associated with any vector
                % Just select randomly
                n_select = min(n_needed, length(remaining));
                random_idx = randperm(length(remaining), n_select);
                selected_indices = [selected_indices; remaining(random_idx)'];
            end
        end
    end
    
    % Ensure we have exactly U solutions
    selected_indices = unique(selected_indices);
    if length(selected_indices) > U
        selected_indices = selected_indices(1:U);
    end
    selected_indices = selected_indices';
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