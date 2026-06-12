classdef ConfigurableHVGSA < ALGORITHM
% <multi> <real/integer/label/binary/permutation> <constrained/none>
% Configurable standalone HVGSA (no EMOA, pure local search)
%
%   A standalone HVGSA local-search algorithm that reuses historical
%   populations to construct neighborhood information in the mu*n
%   concatenated decision space, following the convention of the paper.
%   Each iteration costs only mu function evaluations (one per stepped
%   solution), plus `a` extra evaluations in 'hybrid' mode.
%
%   Three neighbor_mode variants:
%     'archive' (default)
%       Every past population in the archive is used as a neighbor in
%       the mu*n concatenated decision space. The number of available
%       neighbors is bounded by Qsize.
%     'select'
%       Uses SelectNeighbors to pick neighbors of the current team from
%       the archived populations. All mu*n neighbors are accepted
%       without random truncation.
%     'hybrid'
%       Same as 'select', plus up to `a` artificial neighbors generated
%       near the current team each generation (a in [0, mu*n]). When
%       a = mu*n the finite-difference pattern approximates the true
%       hypervolume gradient.
%
%   Bootstrap (variants 'archive' and 'select', or 'hybrid' with a = 0):
%     Because the archive is empty on the first iteration, one set of
%     artificial neighbors is generated and pushed into the archive
%     before entering the main loop, ensuring non-degenerate search
%     directions from iteration 1.
%
%   Usage:
%     % Default (archive mode, Qsize = 50)
%     platemo('algorithm', {@ConfigurableHVGSA, struct()}, ...)
%
%     % Variant 2 — SelectNeighbors against the archive, no truncation
%     platemo('algorithm', {@ConfigurableHVGSA, ...
%         struct('neighbor_mode','select')}, ...)
%
%     % Variant 3 — hybrid with 20 artificial neighbors per generation
%     platemo('algorithm', {@ConfigurableHVGSA, ...
%         struct('neighbor_mode','hybrid','a',20)}, ...)

    methods
        function main(Algorithm, Problem)
            %% Parse config and HID
            [configIn, HID] = Algorithm.ParameterSet(struct(), "");
            config = parseHVGSAConfig(configIn);

            %% Set save name
            variantName = config2name_HVGSA(config);
            Algorithm.SetSaveName(variantName);

            %% Parameters from config
            eta     = config.eta;
            mode    = config.neighbor_mode;
            Qsize   = config.Qsize;
            a_num   = config.a;
            sr_mode = config.sr_mode;
            k_min   = config.k_min;
            delta = config.delta;

            %% Generate population (with optional heuristic initialization)
            Population = initPopulation(Problem, HID);
            mu = numel(Population);
            M  = Problem.M;

            %% Archive of past populations (historical neighborhood info)
            Archive = PopulationQueue(Qsize);

            %% HV caching: when the reference point is fixed for the
            %% entire run *and* we are in 'archive' mode, the HV of any
            %% stored population is time-invariant and can be computed
            %% once at push-time. We store each entry as a struct
            %% {population, hv} so later iterations only require one new
            %% HV evaluation (for the population freshly pushed).
            canCacheHV = ~isempty(config.ref) && strcmp(mode, 'archive');

            %% Cold-start bootstrap: when no artificial neighbors will be
            %% generated during the main loop (archive/select modes, or
            %% hybrid with a = 0), prime the archive with one pass of
            %% artificial neighbors so the first gradient step has a
            %% non-trivial subspace to work with.
            needs_bootstrap = strcmp(mode, 'archive') || ...
                              strcmp(mode, 'select')  || ...
                              (strcmp(mode, 'hybrid') && a_num == 0);
            % if needs_bootstrap
            %     BootNeighbors = GenerateArtificialNeighbors(Population, Problem, "dimensional");
            %     for i = 1:numel(BootNeighbors)
            %         pushArchive(Archive, BootNeighbors{i}, 0, canCacheHV, config.ref);
            %     end
            % end

            %% Counter
            global HV_counter;
            HV_counter = 0;
            iter_counter = 1;
            max_iter = 2000;

            %% Main optimization loop
            while Algorithm.NotTerminated(Population)
                %% Push current population into archive so it can act as
                %% neighborhood information in later iterations. When
                %% caching is active this is the (only) HV evaluation of
                %% this iteration.
                if needs_bootstrap && iter_counter == 1
                    BootNeighbors = GenerateArtificialNeighbors(Population, Problem, "dimensional", delta);
                    for i = 1:numel(BootNeighbors)
                        pushArchive(Archive, BootNeighbors{i}, 0, canCacheHV, config.ref);
                    end
                else
                    pushArchive(Archive, Population, iter_counter, canCacheHV, config.ref);
                end

                X0 = Population;

                %% Build the Neighbors cell array according to mode.
                %% Each entry is a SOLUTION array of the same size as X0
                %% representing one point in the mu*n concatenated space.
                X0_indices = 1:numel(X0);
                HV_Neighbors = [];  % populated only when canCacheHV
                switch mode
                    case 'archive'
                        [Neighbors, HV_Neighbors] = ...
                            collectArchiveNeighbors(Archive, numel(X0), canCacheHV);
                    case 'select'
                        [Neighbors, X0_sub, X0_indices] = ...
                            selectArchiveNeighbors(X0, Archive, sr_mode, k_min);
                        X0 = X0_sub;
                    case 'hybrid'
                        [SelNb, X0_sub, X0_indices] = ...
                            selectArchiveNeighbors(X0, Archive, sr_mode, k_min);
                        X0 = X0_sub;
                        Neighbors = SelNb;
                        if a_num > 0 && ~isempty(X0)
                            Art = GenerateArtificialNeighbors(X0, Problem, "dimensional");
                            take = min(a_num, numel(Art));
                            Neighbors = [Neighbors, Art(1:take)];
                        end
                    otherwise
                        error('ConfigurableHVGSA:badMode', ...
                            'Unknown neighbor_mode: %s', mode);
                end

                %% If there are still no neighbors (possible only for
                %% 'select' with an entirely pruned team), skip this step.
                if isempty(Neighbors) || isempty(X0)
                    iter_counter = iter_counter + 1;
                    continue;
                end

                u = numel(X0);

                %% Reference point for gradient computation
                if canCacheHV
                    ref = config.ref;  % fixed for the whole run
                else
                    cell_objs = cellfun(@(c) c.objs, Neighbors, 'UniformOutput', false);
                    concat_objs = vertcat(cell_objs{:}, X0.objs);
                    if isempty(config.ref)
                        ideal = min(concat_objs, [], 1);
                        nadir = max(concat_objs, [], 1);
                        ref = ideal + 1.2 * (nadir - ideal);
                        % ref = ideal + (1 + 1/max(getRefH(M, u), 1)) * (nadir - ideal);
                    else
                        ref = config.ref;
                    end
                end

                %% Flatten decisions (always needed for the V matrix)
                flat_X0  = Flatten(X0.decs);
                flat_CX0 = Flatten(X0.cons);
                cell_flat_decs = cellfun(@(c) Flatten(c.decs), Neighbors, 'UniformOutput', false);
                flat_Xi = vertcat(cell_flat_decs{:});
                cell_flat_cons = cellfun(@(c) Flatten(c.cons), Neighbors, 'UniformOutput', false);
                flat_CXi = vertcat(cell_flat_cons{:});

                if canCacheHV
                    %% Retrieve HVs from the archive cache. Archive.get(1)
                    %% is the entry just pushed at the top of this loop,
                    %% i.e. the current Population == X0.
                    HV_X0 = Archive.get(1).pop.hv;
                    HV_Xi = HV_Neighbors(:);
                else
                    %% Compute HVs (batched over populations)
                    flat_FX0 = Flatten(X0.objs);
                    cell_flat_objs = cellfun(@(c) Flatten(c.objs), Neighbors, 'UniformOutput', false);
                    flat_FXi = vertcat(cell_flat_objs{:});
                    HV_X0 = FeasibleCHV(ref, flat_FX0, flat_CX0);
                    HV_Xi = FeasibleCHV(ref, flat_FXi, flat_CXi);
                end

                %% Gradient computation
                [v, ~, ~, ~] = callGradient(config, flat_X0, HV_X0, flat_CX0, ...
                                                    flat_Xi, HV_Xi, flat_CXi, u);
                GSA_HVGrad = v';

                %% Step only the kept team members; leave dropped members
                %% in place so the population size is preserved.
                flat_Xs = flat_X0 + eta * GSA_HVGrad;
                Xs_decs = Unflatten(flat_Xs, u);
                Xs_decs = min(Problem.upper, max(Problem.lower, Xs_decs));
                Xs = Problem.Evaluation(Xs_decs);   % u <= mu FEs

                NewPopulation = Population;
                NewPopulation(X0_indices) = Xs;
                Population = NewPopulation;

                iter_counter = iter_counter + 1;

                if iter_counter > max_iter
                    FE_counter = Problem.FE;
                    save('HV_counter.mat', 'HV_counter');
                    save('FE_counter.mat', 'FE_counter');
                    Problem.FE = 1e8;
                end
            end
        end
    end
end

%% ---------- helpers ---------------------------------------------------

function pushArchive(Archive, pop, iter, canCacheHV, ref)
%PUSHARCHIVE  Push a population into the archive, optionally caching its
% HV value alongside it. When canCacheHV is true, the stored object is
% a struct {population, hv}; otherwise the raw population is stored.
    if canCacheHV
        entry = struct();
        entry.population = pop;
        entry.hv = FeasibleCHV(ref, Flatten(pop.objs), Flatten(pop.cons));
        Archive.push(entry, iter);
    else
        Archive.push(pop, iter);
    end
end

function [pop, hv] = unwrapEntry(entryPop)
%UNWRAPENTRY  Normalize an Archive entry to (pop, hv). If the entry was
% cached, hv is the stored scalar; otherwise hv is empty.
    if isstruct(entryPop) && isfield(entryPop, 'population')
        pop = entryPop.population;
        hv  = entryPop.hv;
    else
        pop = entryPop;
        hv  = [];
    end
end

function [Neighbors, HVs] = collectArchiveNeighbors(Archive, u, canCacheHV)
%COLLECTARCHIVENEIGHBORS  Use each past population of size u as one
% neighbor in the mu*n concatenated decision space. Populations of a
% different size are skipped. When canCacheHV is true, the cached HV of
% each kept population is returned in HVs (column vector) so the main
% loop can skip recomputing HV_Xi.
    Neighbors = {};
    HVs = [];
    for i = 1:Archive.getSize()
        entry = Archive.get(i);
        [past_pop, past_hv] = unwrapEntry(entry.pop);
        if numel(past_pop) == u
            Neighbors{end+1} = past_pop; %#ok<AGROW>
            if canCacheHV
                HVs(end+1, 1) = past_hv; %#ok<AGROW>
            end
        end
    end
end

function [Neighbors, X0_prime, X0_indices] = selectArchiveNeighbors(X0, Archive, sr_mode, k_min)
%SELECTARCHIVENEIGHBORS  Flatten the archive into a single SOLUTION array
% and run SelectNeighbors with U = Inf-like bound so that no random
% truncation happens (variant 2 of the three-variant design).
    History = X0;
    for i = 1:Archive.getSize()
        entry = Archive.get(i);
        [past_pop, ~] = unwrapEntry(entry.pop);
        History = [History, past_pop]; %#ok<AGROW>
    end
    [~, uniqIdx] = unique(History.decs, 'rows');
    History = History(uniqIdx);
    U = max(numel(X0), numel(History));  % effectively no truncation
    [Neighbors, X0_prime, X0_indices] = SelectNeighbors(X0, History, sr_mode, k_min, U);
end

function [v, V, lambda, d] = callGradient(config, flat_X0, HV_X0, flat_CX0, flat_Xi, HV_Xi, flat_CXi, u)
%CALLGRADIENT  Dispatch to the correct gradient method.
    switch config.gradient_method
        case 'CGSA_n'
            [v, V, lambda, d] = CGSA_n(flat_X0, HV_X0, flat_CX0, flat_Xi, HV_Xi, flat_CXi, u);
        case 'CGSA'
            [v, V, lambda, d] = CGSA(flat_X0, HV_X0, flat_CX0, flat_Xi, HV_Xi, flat_CXi);
        otherwise
            error('ConfigurableHVGSA:badGradient', ...
                'Unknown gradient_method: %s', config.gradient_method);
    end
end
