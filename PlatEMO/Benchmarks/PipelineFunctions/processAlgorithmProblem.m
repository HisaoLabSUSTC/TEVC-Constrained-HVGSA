function [metricValues, aucValues, numRuns] = processAlgorithmProblem(...
    algorithmName, problemName, feasible, trimmedDir, dataDir, N, runs)
%PROCESSALGORITHMPROBLEM Compute metrics for one (algorithm, problem) pair.
%
%   [metricValues, aucValues, numRuns] = processAlgorithmProblem(...)
%
%   For feasible problems (RWMOP1-35, RWMOP50):
%     metricValues = normalized HV of final population (feasible solutions only)
%     aucValues    = AUC of per-generation normalized HV trajectory
%
%   For infeasible problems (RWMOP36-49):
%     metricValues = average constraint violation of final population
%     aucValues    = -AUC of per-generation average CV trajectory
%
%   File matching uses directory scanning to handle PlatEMO's naming
%   convention: {Alg}_{Prob}_M{M}_D{D}_{Run}.mat
%
%   Input:
%     algorithmName - String name of the algorithm
%     problemName   - String name of the problem (e.g., 'RWMOP1')
%     feasible      - Logical: true = feasible problem, false = infeasible
%     trimmedDir    - Directory with trimmed data (default: './TrimmedData')
%     dataDir       - Directory with raw data (default: './Data')
%     N             - Population size (for HV reference point)
%     runs          - Number of runs (pre-allocation size)
%
%   Output:
%     metricValues - 1 x numRuns array (HV for feasible, CV for infeasible)
%     aucValues    - 1 x numRuns array (AUC-HV for feasible, -AUC-CV for infeasible)
%     numRuns      - Actual number of runs processed

    %% Scan trimmed directory for matching files
    subdirPath = fullfile(trimmedDir, algorithmName);
    if ~exist(subdirPath, 'dir')
        numRuns = 0;
        metricValues = zeros(1, 0);
        aucValues = zeros(1, 0);
        return;
    end

    matFiles = dir(fullfile(subdirPath, '*.mat'));

    % Match: {AlgName}_{ProbName}_M{M}_D{D}_{Run}.mat
    % Also supports simple pattern: {AlgName}_{ProbName}_{Run}.mat
    pattern = sprintf('^%s_%s(_M\\d+_D\\d+)?_\\d+$', ...
        regexptranslate('escape', algorithmName), ...
        regexptranslate('escape', problemName));

    matchingFiles = {};
    for j = 1:length(matFiles)
        [~, fname, ~] = fileparts(matFiles(j).name);
        if ~isempty(regexp(fname, pattern, 'once'))
            matchingFiles{end+1} = matFiles(j).name; %#ok<AGROW>
        end
    end

    if isempty(matchingFiles)
        numRuns = 0;
        metricValues = zeros(1, 0);
        aucValues = zeros(1, 0);
        return;
    end

    %% Preload reference data for feasible problems
    if feasible
        [~, ideal, nadir] = loadReferencePF(problemName);
        M = numel(ideal);
        H = getRefH(M, N);
        % ref = ones(1, M) * (1 + 1/H);
        ref = ones(1, M) * 1.2;
    end

    %% Process each matching file
    nMatched = numel(matchingFiles);
    metricValues = zeros(1, nMatched);
    aucValues = zeros(1, nMatched);

    for j = 1:nMatched
        filename = matchingFiles{j};

        %% Final metric from trimmed data
        data = load(fullfile(subdirPath, filename), 'finalPop');
        finalPop = data.finalPop;

        if feasible
            % Normalized HV of feasible solutions
            popObj = finalPop.objs;
            popCon = finalPop.cons;
            feasObj = filterFeasible(popObj, popCon);
            metricValues(j) = computeNormalizedHV(feasObj, ideal, nadir, ref);
        else
            % Average constraint violation.
            % PPS swaps its working population for a feasibility-filtered
            % archive on the final iteration; when no feasible solution is
            % ever found the archive is empty, so finalPop is empty and
            % finalPop.cons would give a trivial CV of 0. Fall back to the
            % second-to-last snapshot (still the working search population
            % for PPS) by loading the raw result, so the reported CV
            % reflects the actual solutions PPS produced.
            if isempty(finalPop) || isempty(finalPop.cons)
                rawFile = fullfile(dataDir, algorithmName, filename);
                if exist(rawFile, 'file')
                    try
                        rawData = load(rawFile, 'result');
                        if size(rawData.result, 1) >= 2
                            finalPop = rawData.result{end-1, 2};
                        end
                    catch
                        % leave finalPop as-is; metric set to NaN below
                    end
                end
            end
            if isempty(finalPop) || isempty(finalPop.cons)
                metricValues(j) = NaN;
                aucValues(j)    = NaN;
                continue;
            end
            popCon = finalPop.cons;
            metricValues(j) = computeAverageCV(popCon);
        end

        %% AUC from raw data (per-generation trajectory)
        rawFile = fullfile(dataDir, algorithmName, filename);
        if ~exist(rawFile, 'file')
            aucValues(j) = NaN;
            continue;
        end

        try
            rawData = load(rawFile, 'result');
            result = rawData.result;
            nGens = size(result, 1);
            feVals = zeros(1, nGens);
            genMetrics = zeros(1, nGens);

            for g = 1:nGens
                feVals(g) = result{g, 1};
                pop = result{g, 2};

                if feasible
                    gObj = pop.objs;
                    gCon = pop.cons;
                    gFeasObj = filterFeasible(gObj, gCon);
                    genMetrics(g) = computeNormalizedHV(gFeasObj, ideal, nadir, ref);
                else
                    % Empty snapshot (e.g., PPS's final empty feasible
                    % archive) would give a trivial CV of 0; carry forward
                    % the previous generation's value so the AUC reflects
                    % the working search trajectory rather than the
                    % archive swap on the final iteration.
                    if isempty(pop) || isempty(pop.cons)
                        if g > 1
                            genMetrics(g) = genMetrics(g-1);
                        else
                            genMetrics(g) = NaN;
                        end
                    else
                        gCon = pop.cons;
                        genMetrics(g) = computeAverageCV(gCon);
                    end
                end
            end

            auc = computeAUC(genMetrics, feVals);
            if ~feasible
                auc = -auc;  % negate: lower CV = better, so more negative = better
            end
            aucValues(j) = auc;
        catch ME
            warning('processAlgorithmProblem:AUCError', ...
                'AUC computation failed for %s/%s file %s: %s', ...
                algorithmName, problemName, filename, ME.message);
            aucValues(j) = NaN;
        end
    end

    numRuns = nMatched;
end

%% ==================== Local Helper ====================

function feasObj = filterFeasible(popObj, popCon)
%FILTERFEASIBLE Return objectives of feasible solutions only.
    if isempty(popCon)
        feasObj = popObj;
        return;
    end
    totalCV = sum(max(0, popCon), 2);
    feasMask = totalCV <= 0;
    feasObj = popObj(feasMask, :);
end
