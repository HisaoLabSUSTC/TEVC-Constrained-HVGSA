function hypervolume = ComputeHV(X0, ref, mode)
    % Compute initial hypervolume and directional derivative
    flat_FX0 = Flatten(X0.objs);
    flat_CX0 = Flatten(X0.cons);

    if mode == "Linear"
        hypervolume = LinearCHV(ref, flat_FX0, flat_CX0);
    elseif mode == "Feasible"
        hypervolume = FeasibleCHV(ref, flat_FX0, flat_CX0);
    elseif mode == "Infeasible"
        hypervolume = InfeasibleCHV(ref, flat_FX0, flat_CX0);
    end
end

