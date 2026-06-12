function [NormPopCons, ideal, nadir] = NormalizeCon(PopCons, eps)
    if nargin < 2
        eps = 1e-6;
    end
    %% - and 0 maps to 0, max maps to 1

    PopCons(PopCons<=0) = 0;
    
    ideal = IdealGetter(PopCons);
    nadir = NadirGetter(PopCons);
    
    NormPopCons = (PopCons - ideal)./(nadir - ideal + eps);
end