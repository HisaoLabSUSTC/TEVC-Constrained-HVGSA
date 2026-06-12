function hv = computeNormalizedHV(popObj, ideal, nadir, ref)
%COMPUTENORMALIZEDHV Compute hypervolume in normalized [0,1] objective space.
%
%   hv = computeNormalizedHV(popObj, ideal, nadir, ref)
%
%   Normalizes objectives to [0,1] using ideal/nadir from the reference PF,
%   then computes the dominated hypervolume with the given reference point.
%
%   Input:
%     popObj - N x M matrix of objective values (should be feasible solutions only)
%     ideal  - 1 x M ideal point (min per objective from reference PF)
%     nadir  - 1 x M nadir point (max per objective from reference PF)
%     ref    - 1 x M reference point in normalized space (e.g., [1+1/H, ..., 1+1/H])
%
%   Output:
%     hv - Hypervolume value (0 if no valid solutions)

    if isempty(popObj)
        hv = 0;
        return;
    end

    % Normalize to [0,1]
    range = nadir - ideal;
    range(range < 1e-12) = 1e-12;  % avoid division by zero
    popObj_norm = (popObj - ideal) ./ range;

    % Only keep solutions that are strictly dominated by the reference point
    valid = all(popObj_norm < ref, 2);
    if ~any(valid)
        hv = 0;
        return;
    end

    hv = stk_dominatedhv(popObj_norm(valid, :), ref);
end
