function [Norm_NeighborArr, Norm_X0, X0_indices] = NormSelectNeighbors(X0, Archive, mode, k_min, U, Problem, NormStruct)
    % NeighborArr is a cell array of Populations
    % containing the neighbors of X0 as a point in N\mu-space

    % Both X0 and Archive contains the SOLUTION array holding
    % population information
    %---------------------------------------------------------

    % Preprocessing
    X0_decs = X0.decs;
    [~, D] = size(X0_decs);
    Archive_decs = Archive.decs;
    X0_indices = 1:numel(X0);

    [Unique_decs, Unique_idx] = unique(Archive_decs, 'rows');

    %% Compute all squared distances at once (vectorized)
    AllDist2 = pdist2(Unique_decs, X0_decs).^2;  % [nUnique x mu]

    %% Sort each column (each team member's distances)
    [AllDist2_sorted, sort_order] = sort(AllDist2, 1);

    mu = numel(X0);
    sq_dist_cells = cell(1, mu);
    idx_cells     = cell(1, mu);
    for i = 1:mu
        sq_dist_cells{i} = AllDist2_sorted(:, i);
        idx_cells{i}     = Unique_idx(sort_order(:, i));
    end

    %% Compute search radius from (D+1)-th nearest neighbor distances
    row_idx = min(size(AllDist2_sorted, 1), D+1);
    dplus1_dists = AllDist2_sorted(row_idx, :);

    switch mode
        case 'min',    sr2 = min(dplus1_dists);
        case 'mean',   sr2 = mean(dplus1_dists);
        case 'median', sr2 = median(dplus1_dists);
        case 'max',    sr2 = max(dplus1_dists);
        otherwise
            error('NormSelectNeighbors:badMode', 'Unknown mode: %s', mode);
    end

    sr2 = max(sr2, 1e-4);

    selected_indices = find_max_column(sq_dist_cells, sr2);
    keep = selected_indices > k_min;

    if ~any(keep)
        Norm_NeighborArr = {};
        Norm_X0 = NormSolution(X0, Problem, NormStruct);
        return
    end

    X0_prime          = X0(keep);
    X0_indices        = X0_indices(keep);
    selidx_kept       = selected_indices(keep);
    idx_cells_kept    = idx_cells(keep);

    if numel(X0_prime) > U
        %% Random Selection
        indices = randperm(numel(X0_prime), U);
        X0_prime = X0_prime(indices);
        X0_indices = X0_indices(indices);
        selidx_kept       = selidx_kept(indices);
        idx_cells_kept    = idx_cells_kept(indices);
    end

    mu_prime = numel(X0_prime);
    Norm_X0 = NormSolution(X0_prime, Problem, NormStruct);

    %% Generate indices matrix:
    indices_matrix = set_combs_from_indices(selidx_kept, D);

    [r, ~] = size(indices_matrix);
    out = zeros(r, mu_prime);
    for col = 1:mu_prime
        map = idx_cells_kept{col};
        out(:, col) = map( indices_matrix(:, col) );
    end

    Norm_Archive = NormSolution(Archive, Problem, NormStruct);
    Norm_NeighborArr = arrayfun(@(i) Norm_Archive(out(i, :)), 1:r, 'UniformOutput', false);
end
