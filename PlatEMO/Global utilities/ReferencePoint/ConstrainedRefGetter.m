function ref = ConstrainedRefGetter(Population, refConstant, ineq_idx, eq_idx)
    invRefConstant = 2 - refConstant;

    PopObj = Population.objs;
    
    c0 = Population.cons;
    if numel(ineq_idx) == 0
        g_CV = [];
    else
        g_CV = sum(max(0, c0(:, ineq_idx)), 2);
    end

    if numel(eq_idx) == 0
        h_CV = [];
    else
        h_CV = sum(c0(:, eq_idx), 2);
    end

    combinedObj = [PopObj, g_CV, h_CV];
    ref = max(combinedObj,[],1);

    % Check if any values in maxPopObj are negative
    for i = 1:length(ref)
        if ref(i) < 0
            % For negative values, apply invRefConstant
            ref(i) = ref(i) * invRefConstant;
        elseif ref(i) == 0
            ref(i) = ref(i) + 1; % for zero values, apply a transformation
        else
            % For positive values, apply refConstant
            ref(i) = ref(i) * refConstant;
        end
    end
end