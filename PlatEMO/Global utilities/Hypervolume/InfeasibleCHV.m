function Infeasible_HV = InfeasibleCHV(ref, flat_FX, flat_CX)
    %% Linearly interpolate between feasible/totally infeasible solutions
    %% to obtain an interpolated hypervolume.

    [r,~] = size(flat_FX);
    M = size(ref, 2);
    N = size(flat_FX, 2)/M;
    Infeasible_HV = zeros(r, 1);

    % flat -> nonflat: reshape(flat, [], N)'

    for i=1:r
       flat_obj = flat_FX(i,:);
       flat_con = flat_CX(i,:);
       obj = reshape(flat_obj,[],N)';
       % con = reshape(flat_con,[],N)';

       fixed_obj = obj; % Don't need to fix at all
       Infeasible_HV(i) = stk_dominatedhv(fixed_obj,ref);  
    end
end

