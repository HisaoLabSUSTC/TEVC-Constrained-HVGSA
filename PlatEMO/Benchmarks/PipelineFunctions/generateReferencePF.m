function generateReferencePF(problemHandles, problemNames, isFeasible, params)
%GENERATEREFERENCEPF Generate reference Pareto fronts for feasible RWMOP problems.
%
%   generateReferencePF(problemHandles, problemNames, isFeasible)
%   generateReferencePF(problemHandles, problemNames, isFeasible, params)
%
%   For each feasible problem, runs multiple SOTA algorithms with a large
%   FE budget over multiple runs, concatenates all feasible non-dominated
%   solutions, and saves the result as the reference Pareto front.
%
%   Infeasible problems (RWMOP36-49) are skipped since they have no
%   feasible region and are evaluated by constraint violation instead.
%
%   Parallelized: all (problem, algorithm, run) tasks run in a single
%   parfor loop. Intermediate results are saved to temp files, then
%   combined per problem.
%
%   Input:
%     problemHandles - Cell array of problem function handles
%     problemNames   - Cell array of problem name strings
%     isFeasible     - Logical vector (true = feasible, false = infeasible)
%     params         - (optional) Struct with fields:
%                        refFE   - FE budget per reference run (default: 300000)
%                        refN    - Population size (default: 200)
%                        refRuns - Runs per algorithm (default: 5)
%                        targetN - Max PF points to retain (default: 3000)
%                        refAlgs - Cell array of algorithm handles
%
%   Output:
%     Saves RefPF-{probName}.mat to ./Info/ReferencePF/ for each feasible problem.
%     Each file contains variables:
%       'PF' (N x M matrix of objective values)
%       'PS' (N x D matrix of decision variables)

    if nargin < 4, params = struct(); end

    refFE   = getFieldDefault(params, 'refFE', 10000 * 120);
    refN    = getFieldDefault(params, 'refN', 120);
    refRuns = getFieldDefault(params, 'refRuns', 21);
    targetN = getFieldDefault(params, 'targetN', 3000);

    if isfield(params, 'refAlgs')
        refAlgs = params.refAlgs;
    else
        refAlgs = {@NSGAII, @CMOEACD, @ICMA};
    end

    outputDir = './Info/ReferencePF';
    if ~exist(outputDir, 'dir'), mkdir(outputDir); end

    tempDir = fullfile(outputDir, 'TempRuns');
    if ~exist(tempDir, 'dir'), mkdir(tempDir); end

    fprintf('=== Generating Reference Pareto Fronts ===\n');
    fprintf('Algorithms: %d, FE: %d, N: %d, Runs: %d per algorithm\n', ...
        numel(refAlgs), refFE, refN, refRuns);

    feasibleIdx = find(isFeasible);

    % Filter to problems that still need reference PFs
    needsGeneration = false(size(feasibleIdx));
    for fi = 1:numel(feasibleIdx)
        i = feasibleIdx(fi);
        outPath = fullfile(outputDir, sprintf('RefPF-%s.mat', problemNames{i}));
        if exist(outPath, 'file')
            fprintf('  %s: already exists, skipping.\n', problemNames{i});
        else
            needsGeneration(fi) = true;
        end
    end
    feasibleIdx = feasibleIdx(needsGeneration);

    if isempty(feasibleIdx)
        fprintf('All reference PFs already exist. Nothing to do.\n');
        return;
    end

    fprintf('Generating PFs for %d feasible problems (skipping %d infeasible)\n\n', ...
        numel(feasibleIdx), sum(~isFeasible));

    %% Phase 1: Build task list and run all (problem, algorithm, run) in parallel
    nProbs = numel(feasibleIdx);
    nAlgs  = numel(refAlgs);
    [Pi, Ai, Ri] = ndgrid(1:nProbs, 1:nAlgs, 1:refRuns);
    tasks = [Pi(:), Ai(:), Ri(:)];
    nTasks = size(tasks, 1);

    % Pre-extract handles/names for parfor (avoid indexing into cell of cells)
    taskProbHandles = cell(nTasks, 1);
    taskProbNames   = cell(nTasks, 1);
    taskAlgHandles  = cell(nTasks, 1);
    taskAlgNames    = cell(nTasks, 1);
    for t = 1:nTasks
        pi = feasibleIdx(tasks(t, 1));
        ai = tasks(t, 2);
        taskProbHandles{t} = problemHandles{pi};
        taskProbNames{t}   = problemNames{pi};
        taskAlgHandles{t}  = refAlgs{ai};
        taskAlgNames{t}    = func2str(refAlgs{ai});
    end
    taskRuns = tasks(:, 3);

    fprintf('Starting %d parallel tasks (%d problems x %d algorithms x %d runs)...\n', ...
        nTasks, nProbs, nAlgs, refRuns);

    parfor t = 1:nTasks
        probName = taskProbNames{t};
        algName  = taskAlgNames{t};
        r        = taskRuns(t);

        % Check if this task was already completed (temp file exists)
        tempFile = fullfile(tempDir, sprintf('Ref_%s_%s_%d.mat', probName, algName, r));
        if isfile(tempFile)
            fprintf('  [%d/%d] %s / %s run %d: temp exists, skipping.\n', ...
                t, nTasks, probName, algName, r);
            continue;
        end

        fprintf('  [%d/%d] %s / %s run %d... ', t, nTasks, probName, algName, r);
        try
            [decs, objs, cons] = platemo( ...
                'algorithm', taskAlgHandles{t}, ...
                'problem',   taskProbHandles{t}, ...
                'N',         refN, ...
                'maxFE',     refFE);

            parsave_ref(tempFile, decs, objs, cons);
            fprintf('done (%d solutions)\n', size(objs, 1));
        catch ME
            fprintf('ERROR: %s\n', ME.message);
        end
    end

    fprintf('\nAll parallel runs complete.\n\n');

    %% Phase 2: Combine results per problem
    for fi = 1:numel(feasibleIdx)
        i = feasibleIdx(fi);
        probName = problemNames{i};

        outPath = fullfile(outputDir, sprintf('RefPF-%s.mat', probName));
        if exist(outPath, 'file')
            continue;  % generated between phases (unlikely but safe)
        end

        fprintf('Combining results for %s... ', probName);

        allDecs = [];
        allObjs = [];
        allCons = [];

        for a = 1:nAlgs
            algName = func2str(refAlgs{a});
            for r = 1:refRuns
                tempFile = fullfile(tempDir, sprintf('Ref_%s_%s_%d.mat', probName, algName, r));
                if ~isfile(tempFile)
                    continue;
                end
                data = load(tempFile, 'decs', 'objs', 'cons');
                allDecs = [allDecs; data.decs]; %#ok<AGROW>
                allObjs = [allObjs; data.objs]; %#ok<AGROW>
                if ~isempty(data.cons)
                    allCons = [allCons; data.cons]; %#ok<AGROW>
                end
            end
        end

        if isempty(allObjs)
            fprintf('WARNING: no solutions collected, skipping.\n');
            continue;
        end

        fprintf('%d total, ', size(allObjs, 1));

        % Filter to feasible solutions only
        if ~isempty(allCons) && size(allCons, 1) == size(allObjs, 1)
            totalCV = sum(max(0, allCons), 2);
            feasibleMask = totalCV <= 0;
            allDecs = allDecs(feasibleMask, :);
            allObjs = allObjs(feasibleMask, :);
            fprintf('%d feasible, ', size(allObjs, 1));
        end

        if isempty(allObjs)
            fprintf('WARNING: no feasible solutions, skipping.\n');
            continue;
        end

        % Remove duplicates (use index to keep decs in sync)
        [allObjs, uIdx] = unique(allObjs, 'rows');
        allDecs = allDecs(uIdx, :);

        % Non-dominated sorting — keep rank 1 only
        frontRank = NDSort(allObjs, 1);
        ndMask = frontRank == 1;
        PF = allObjs(ndMask, :);
        PS = allDecs(ndMask, :);
        fprintf('%d non-dominated', size(PF, 1));

        % Truncate if needed
        if size(PF, 1) > targetN
            idx = randperm(size(PF, 1), targetN);
            idx = sort(idx);
            PF = PF(idx, :);
            PS = PS(idx, :);
            fprintf(' -> truncated to %d', targetN);
        end

        save(outPath, 'PF', 'PS');
        fprintf(', saved (%d obj, %d dec).\n', size(PF, 2), size(PS, 2));

        % Clean up temp files for this problem
        for a = 1:nAlgs
            algName = func2str(refAlgs{a});
            for r = 1:refRuns
                tempFile = fullfile(tempDir, sprintf('Ref_%s_%s_%d.mat', probName, algName, r));
                if isfile(tempFile), delete(tempFile); end
            end
        end
    end

    % Remove temp directory if empty
    if exist(tempDir, 'dir')
        remaining = dir(fullfile(tempDir, '*.mat'));
        if isempty(remaining), rmdir(tempDir); end
    end

    fprintf('\n=== Reference PF generation complete ===\n');
end

%% ==================== Helpers ====================

function parsave_ref(filepath, decs, objs, cons)
%PARSAVE_REF Save decisions, objectives, and constraints inside parfor.
    save(filepath, 'decs', 'objs', 'cons', '-v6');
end

function val = getFieldDefault(s, field, default)
    if isfield(s, field)
        val = s.(field);
    else
        val = default;
    end
end
