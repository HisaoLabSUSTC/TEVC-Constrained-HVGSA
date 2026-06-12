function [NormPopulation, NormStruct] = NormSolution(Population, Problem, NormStruct, eps)
    if nargin < 4
        eps = 1e-6;
    end

    if nargin < 3
        NormStruct = struct();
    end

    Cons = Population.cons;
    Objs = Population.objs;
    Decs = Population.decs;

    Cons(Cons<=0) = 0;

    if isempty(fieldnames(NormStruct))
        %% No ideal/nadir.
        objs_ideal = IdealGetter(Objs);
        objs_nadir = NadirGetter(Objs);
        cons_ideal = IdealGetter(Cons);
        cons_nadir = NadirGetter(Cons);
        NormStruct.objs_ideal = objs_ideal;
        NormStruct.objs_nadir = objs_nadir;
        NormStruct.cons_ideal = cons_ideal;
        NormStruct.cons_nadir = cons_nadir;
        NormStruct.norm_eps = eps;
    else
        objs_ideal = NormStruct.objs_ideal;
        objs_nadir = NormStruct.objs_nadir;
        cons_ideal = NormStruct.cons_ideal;
        cons_nadir = NormStruct.cons_nadir;
        eps = NormStruct.norm_eps;
    end

    lower = Problem.lower;
    upper = Problem.upper;

    NormDecs = (Decs - lower)./(upper - lower);
    NormObjs = (Objs - objs_ideal)./(objs_nadir - objs_ideal + eps);
    % NormObjs(NormObjs > 1) = 1; % Will this be a problem? It seems unjustified.
    % NormObjs(NormObjs < 0) = 0;
    NormCons = (Cons - cons_ideal)./(cons_nadir - cons_ideal + eps);
    % NormCons(NormCons > 1) = 1; % I also think this might not be needed.
    % NormCons(NormCons < 0) = 0;
    NormPopulation = SOLUTION(NormDecs, NormObjs, NormCons);
end