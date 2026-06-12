function Linear_HV = LinearCHV(ref, flat_FX, flat_CX)
    %% Linearly interpolate between feasible/totally infeasible solutions
    %% to obtain an interpolated hypervolume.

    [r,~] = size(flat_FX);
    M = size(ref, 2);
    N = size(flat_FX, 2)/M;
    p = size(flat_CX, 2)/N;

    Linear_HV = zeros(r, 1);

    % flat -> nonflat: reshape(flat, [], N)'

    for i=1:r
       flat_obj = flat_FX(i,:);
       flat_con = flat_CX(i,:);
       obj = reshape(flat_obj,[],N)';
       con = reshape(flat_con,[],N)';

       coeff_matrix = con ./ p;
       coeff = sum(coeff_matrix,2);
       % coeff = sum(con,2);

       % disp(coeff);

       ref_vecs = ref - obj;
       offset = ref_vecs .* coeff;

       fixed_obj = obj + offset;

       Linear_HV(i) = stk_dominatedhv(fixed_obj,ref);  
    end
end

