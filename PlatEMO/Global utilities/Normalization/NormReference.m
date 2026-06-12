function [NormObjs, NormCons, NormStruct] = NormReference(Objs, Cons, NormStruct, eps)
    if nargin < 4
        eps = 1e-6;
    end

    if nargin < 3
        NormStruct = struct();
    end

    Cons(Cons<=0) = 0;

    if ~isfield(NormStruct, 'objs_ideal')
        %% No ideal/nadir — first call, compute and store.
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

    NormObjs = (Objs - objs_ideal)./(max(objs_nadir - objs_ideal, eps));

    if isfield(NormStruct, 'normalize_cons') && ~NormStruct.normalize_cons
        NormCons = Cons;
    else
        NormCons = (Cons - cons_ideal)./(max(cons_nadir - cons_ideal, eps));
    end
end