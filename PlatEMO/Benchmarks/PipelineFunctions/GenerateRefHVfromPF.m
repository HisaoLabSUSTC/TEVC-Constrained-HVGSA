function GenerateRefHVfromPF(problemHandles, problemNames, isFeasible, N)
%GENERATEREFHVFROMPF Compute reference hypervolume in normalized [0,1] space.
%
%   GenerateRefHVfromPF(problemHandles, problemNames, isFeasible, N)
%
%   For each feasible problem, loads the stored reference PF, normalizes
%   to [0,1] using the ideal/nadir derived from the PF, and computes the
%   maximum obtainable HV with reference point [1+1/H, ..., 1+1/H]
%   where H = getRefH(M, N) (Ishibuchi et al.).
%
%   Infeasible problems (RWMOP36-49) are skipped.
%
%   Input:
%     problemHandles - Cell array of problem function handles
%     problemNames   - Cell array of problem name strings
%     isFeasible     - Logical vector (true = feasible)
%     N              - Population size (scalar or per-problem vector)
%
%   Output:
%     Saves prob2rhv map to ./Info/FinalHV/ReferenceHV/prob2rhv.mat
%     Keys are problem names, values are reference HV in normalized space.

    fprintf('=== Computing Reference Hypervolumes (normalized [0,1] space) ===\n');

    % Support both scalar N and per-problem N vector
    if isscalar(N)
        N_vec = repmat(N, 1, numel(problemHandles));
    else
        N_vec = N;
    end

    prob2rhv = containers.Map();
    feasibleIdx = find(isFeasible);

    for fi = 1:numel(feasibleIdx)
        i = feasibleIdx(fi);
        probName = problemNames{i};
        N_i = N_vec(i);

        fprintf('  [%d/%d] %s: ', fi, numel(feasibleIdx), probName);

        % Load stored reference PF
        try
            [PF, ideal, nadir] = loadReferencePF(probName);
        catch ME
            fprintf('SKIPPED (%s)\n', ME.message);
            continue;
        end

        M = size(PF, 2);

        % Normalize PF to [0,1]
        range = nadir - ideal;
        range(range < 1e-12) = 1e-12;  % avoid division by zero
        PF_norm = (PF - ideal) ./ range;

        % HV reference point: 1 + 1/H (Ishibuchi et al.)
        H = getRefH(M, N_i);
        ref = ones(1, M) * (1 + 1/H);

        % Compute maximum obtainable HV
        hv = stk_dominatedhv(PF_norm, ref);
        prob2rhv(probName) = hv;

        fprintf('M=%d, N=%d, H=%d, refHV = %.6f\n', M, N_i, H, hv);
    end

    % Save
    outDir = './Info/FinalHV/ReferenceHV';
    if ~exist(outDir, 'dir'), mkdir(outDir); end
    save(fullfile(outDir, 'prob2rhv.mat'), 'prob2rhv');
    fprintf('\nSaved prob2rhv (%d entries) to %s\n', prob2rhv.Count, outDir);
end
