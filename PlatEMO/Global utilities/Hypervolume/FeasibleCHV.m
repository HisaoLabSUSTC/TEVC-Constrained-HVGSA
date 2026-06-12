function Feasible_HV = FeasibleCHV(ref, flat_FX, flat_CX)
    %% Only compute hypervolume for feasible solutions

    [r,~] = size(flat_FX);
    M = size(ref, 2);
    N = size(flat_FX, 2)/M;
    Feasible_HV = zeros(r, 1);

    % flat -> nonflat: reshape(flat, [], N)'

    for i=1:r
       flat_obj = flat_FX(i,:);
       flat_con = flat_CX(i,:);
       obj = reshape(flat_obj,[],N)';
       con = reshape(flat_con,[],N)';

       infeasible_idx = any(con > 0, 2);
       fixed_obj = obj(~infeasible_idx,:);

       Feasible_HV(i) = stk_dominatedhv(fixed_obj,ref);  
    end
end

