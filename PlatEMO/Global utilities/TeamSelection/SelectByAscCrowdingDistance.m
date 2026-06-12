function selected_indices = SelectByAscCrowdingDistance(Population, U)
    % Select diverse solutions using crowding distance
    
    objs = Population.objs;
    n = size(objs, 1);

    % Calculate crowding distances
    crowd_dist = CrowdingDistance(objs);
    
    % Prioritize high crowding distance (sparse regions)
    [~, sorted_idx] = sort(crowd_dist, 'ascend');
    selected_indices = sorted_idx(1:U);
end