function selected_indices = SelectByDescDensity(Population, U)
    % Select diverse solutions using crowding distance
    
    objs = Population.objs;

    [N, M] = size(objs);

    Distance = pdist2(objs, objs);
    Distance(logical(eye(length(Distance)))) = inf;
    Distance = sort(Distance,2);

    D = 1./(Distance(:,floor(sqrt(N)))+2);
    [~, sorted_idx] = sort(D, 'descend');

    selected_indices = sorted_idx(1:U)';
end
