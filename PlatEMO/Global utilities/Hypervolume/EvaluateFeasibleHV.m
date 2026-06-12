function hypervolume = EvaluateFeasibleHV(X0, Problem, ref)
    % Compute initial hypervolume and directional derivative
    feas_rows = all(X0.cons <= 0, 2);
    X0 = X0(feas_rows);

    flat_FX0 = Flatten(X0.objs);

    disp(size(X0.decs));
    disp(size(X0.objs));
    disp(size(X0.cons));
    disp(size(ref));
    hypervolume = Hypervolume(flat_FX0, ref);
end

