function generateInitialPopulations(problemHandles, N, runs, outputDir, problemNames)
%GENERATEINITIALPOPULATIONS Generate and save shared initial populations
%
%   generateInitialPopulations(problemHandles, N, runs, outputDir, problemNames)
%
%   For each (problem, run) pair, generates a random initial population of
%   size N and saves the decision variables to a .mat file. This ensures
%   all algorithms start from the same initial population for fair comparison.
%
%   Input:
%     problemHandles - Cell array of problem function handles
%     N              - Population size (scalar or per-problem vector)
%     runs           - Number of independent runs
%     outputDir      - Output directory (default: './Info/InitialPopulation')
%     problemNames   - Cell array of problem name strings
%
%   Output files:
%     {outputDir}/HS-{ProblemName}_{Run}.mat containing 'heuristic_solutions'

    if nargin < 4 || isempty(outputDir)
        outputDir = './Info/InitialPopulation';
    end
    if nargin < 5
        problemNames = cellfun(@func2str, problemHandles, 'UniformOutput', false);
    end

    % Support both scalar N and per-problem N vector
    if isscalar(N)
        N_vec = repmat(N, 1, numel(problemHandles));
    else
        N_vec = N;
    end

    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end

    fprintf('=== Generating Initial Populations ===\n');
    fprintf('Problems: %d, Runs: %d\n', numel(problemHandles), runs);

    for p = 1:numel(problemHandles)
        probName = problemNames{p};
        N_p = N_vec(p);

        for r = 1:runs
            outFile = fullfile(outputDir, sprintf('HS-%s_%d.mat', probName, r));

            % Skip if already exists
            if exist(outFile, 'file')
                continue;
            end

            % Seed RNG for reproducibility: unique seed per (problem, run)
            rng(42 + r);

            % Instantiate problem to get bounds and D
            pro = problemHandles{p}();
            lower = pro.lower;
            upper = pro.upper;
            D = pro.D;

            % Generate random decision variables within bounds
            heuristic_solutions = repmat(lower, N_p, 1) + ...
                rand(N_p, D) .* repmat(upper - lower, N_p, 1);

            % Save
            save(outFile, 'heuristic_solutions', '-v6');
        end

        fprintf('  %s: N=%d, %d initial populations generated\n', probName, N_p, runs);
    end

    fprintf('=== Initial population generation complete ===\n');
end
