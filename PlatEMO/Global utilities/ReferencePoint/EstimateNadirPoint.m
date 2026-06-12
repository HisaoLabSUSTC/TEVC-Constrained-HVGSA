function nadir_point = EstimateNadirPoint(PopObjs, Multiplier)
    ideal = min(PopObjs,[],1);
    nadir = max(PopObjs,[],1);

    nadir_point = ideal + Multiplier * (nadir-ideal);
end

% a = ideal + 1.2 * (nadir - ideal)
% b = ideal
% 
% want: max
% a = 1.2*max - 0.2*min
% b = min
% 
% (a + 0.2*b)/1.2
