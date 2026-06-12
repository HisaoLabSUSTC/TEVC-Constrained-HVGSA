function [NormPopObjs, ideal, nadir] = NormalizeObj(PopObjs, eps)
    if nargin < 2
        eps = 1e-6;
    end

    ideal = IdealGetter(PopObjs);
    nadir = NadirGetter(PopObjs);
    
    NormPopObjs = (PopObjs - ideal)./(nadir - ideal + eps);
end