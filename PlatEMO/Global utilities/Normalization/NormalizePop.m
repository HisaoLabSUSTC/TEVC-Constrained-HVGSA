function NormPop = NormalizePop(Population, norm_eps)
    if nargin < 2
        norm_eps = 1e-6;
    end
    [NormObjs,~,~] = NormalizeObj(Population.objs, norm_eps);
    [NormCons,~,~] = NormalizeCon(Population.cons, norm_eps);
    NormPop = SOLUTION(Population.decs,NormObjs,NormCons);
end

