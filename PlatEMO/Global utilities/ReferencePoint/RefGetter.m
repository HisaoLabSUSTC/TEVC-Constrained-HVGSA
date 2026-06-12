function ref = RefGetter(PopObjs, refConstant)
    invRefConstant = 2 - refConstant;
    
    ref = max(PopObjs,[],1);
    
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