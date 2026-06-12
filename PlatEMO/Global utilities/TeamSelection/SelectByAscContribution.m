function selected_indices = SelectByAscContribution(Population, ref, U)
    % Select U solutions with highest hypervolume contributions
    
    objs = Population.objs;
    n = size(objs, 1);
    contributions = zeros(n, 1);
    
    % Compute each solution's exclusive hypervolume
    for i = 1:n
        % HV with all solutions
        hv_all = stk_dominatedhv(objs, ref);
        
        % HV without solution i
        hv_without = stk_dominatedhv(objs([1:i-1, i+1:end], :), ref);
        
        contributions(i) = hv_all - hv_without;
    end
    
    % Select top U contributors
    [~, sorted_idx] = sort(contributions, 'ascend');
    selected_indices = sorted_idx(1:U)';
end