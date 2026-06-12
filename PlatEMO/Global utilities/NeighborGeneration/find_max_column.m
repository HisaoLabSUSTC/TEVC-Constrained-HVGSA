function selected_indices = find_max_column(costs, r)
    n = length(costs);
    selected_indices = zeros(1, n);
    
    % Convert to cell array if needed
    if ~iscell(costs)
        costs = num2cell(costs, 2);
    end
    
    for i = 1:n
        current_list = costs{i};
        idx = find(current_list < r, 1, 'last');
        selected_indices(i) = idx;
    end
end