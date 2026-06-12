function sanityCheckInitPop(algorithms, problem, run_idx)
%SANITYCHECKINITPOP Verify that all algorithms share the same initial population
%
%   sanityCheckInitPop(algorithms, problem, run_idx)
%
%   Loads the first-generation data for each algorithm on the given problem
%   and run index, then checks that all initial decision variables match.
%
%   Input:
%     algorithms - Cell array of algorithm specs (handles or config cells)
%     problem    - Problem function handle (e.g. @RWMOP10)
%     run_idx    - Run number to check (integer)
%
%   Example:
%     algorithms = { @CMOEACDwH, @ICMAwH, @NSGAIIwH, @PPSwH, @CMOEADwH, generateCHVGSA() };
%     sanityCheckInitPop(algorithms, @RWMOP10, 1);

    prob_name = func2str(problem);
    nAlg = numel(algorithms);

    %% Load first-generation decision variables for each algorithm
    algNames = cell(1, nAlg);
    firstDecs = cell(1, nAlg);

    for i = 1:nAlg
        algNames{i} = getAlgorithmName(algorithms{i});
        folder = fullfile('Data', algNames{i});

        % Find matching file using glob (handles unknown M/D)
        pattern = fullfile(folder, sprintf('%s_%s_*_%d.mat', algNames{i}, prob_name, run_idx));
        matches = dir(pattern);

        if isempty(matches)
            error('No data file found for %s on %s run %d.\n  Pattern: %s', ...
                algNames{i}, prob_name, run_idx, pattern);
        end
        if numel(matches) > 1
            warning('Multiple files match for %s — using first: %s', algNames{i}, matches(1).name);
        end

        filepath = fullfile(matches(1).folder, matches(1).name);
        d = load(filepath, 'result');
        pop = d.result{1, 2};       % First generation SOLUTION array
        firstDecs{i} = pop.decs;

        fprintf('[%d] %-20s  file: %s  pop size: %d x %d\n', ...
            i, algNames{i}, matches(1).name, size(firstDecs{i}, 1), size(firstDecs{i}, 2));
    end

    %% Compare all against the first algorithm
    refDecs = firstDecs{1};
    refName = algNames{1};
    allMatch = true;

    fprintf('\n=== Pairwise comparison (reference: %s) ===\n', refName);
    for i = 2:nAlg
        if isequal(size(refDecs), size(firstDecs{i})) && all(abs(refDecs - firstDecs{i}) < 1e-8, 'all')
            fprintf('  %s vs %s : MATCH\n', refName, algNames{i});
        else
            fprintf('  %s vs %s : MISMATCH\n', refName, algNames{i});
            allMatch = false;
        end
    end

    if allMatch
        fprintf('\nAll %d algorithms share the same initial population.\n', nAlg);
    else
        fprintf('\nWARNING: Not all algorithms share the same initial population!\n');
    end

    %% Eyeball test — print first 5 solutions' decision variables
    fprintf('\n=== First 15 solutions'' decision variables ===\n');
    nShow = min(15, size(refDecs, 1));
    for i = 1:nAlg
        fprintf('\n--- %s ---\n', algNames{i});
        disp(firstDecs{i}(1:nShow, :));
    end
end
