function ref = CRefGetter(PopObjs, PopCons, refConstant)
    invRefConstant = 2 - refConstant;
    
    %% 0 value of PopCons -> 1
    %% tiny value of PopCons -> 1 + tiny
    PopCVs = sum(PopCons, 2) + 1;
    PopObjCons = [PopObjs, PopCVs];
    ref = max(PopObjCons,[],1);
    
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