function extractMedianRun(algorithms, problemNames, isFeasible)
%EXTRACTMEDIANRUN Extract median metric runs for visualization
%
%   extractMedianRun(algorithms, problemNames, isFeasible)
%
%   For each (algorithm, problem) pair, identifies the run closest to the
%   median metric value:
%     - Feasible problems: median based on final normalized HV (from prob2hv)
%     - Infeasible problems: median based on final average CV (from prob2cv)
%
%   Input:
%     algorithms   - Cell array of algorithm specs (handles or config cells)
%     problemNames - Cell array of problem name strings
%     isFeasible   - Logical vector (true = feasible, false = infeasible)
%
%   Output:
%     Saves ./Info/MedianResults/Median_{algName}.mat containing:
%       results.{probField}.medianValue  - Median metric value
%       results.{probField}.medianIdx    - Run index closest to median
%       results.{probField}.allValues    - All run metric values
%       results.{probField}.numRuns      - Number of runs
%       results.{probField}.medianFile   - Expected data filename
%       results.{probField}.metric       - 'HV' or 'CV'

    hvDir   = './Info/FinalHV';
    cvDir   = './Info/FinalCV';
    dataDir = './Data';
    outDir  = './Info/MedianResults';
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    for ah = 1:numel(algorithms)
        algName = getAlgorithmName(algorithms{ah});
        results = struct();
        hasAny  = false;

        % Scan Data directory once per algorithm to build run-file map
        algDataDir = fullfile(dataDir, algName);

        for p = 1:numel(problemNames)
            prob = problemNames{p};
            fprintf('Processing %s - %s (%d/%d)\n', algName, prob, p, numel(problemNames));

            if isFeasible(p)
                % Feasible: use HV (higher is better, but median selection
                % is metric-agnostic — just find closest to median)
                values = loadMapValues(hvDir, algName, 'prob2hv', prob);
                metricName = 'HV';
            else
                % Infeasible: use CV
                values = loadMapValues(cvDir, algName, 'prob2cv', prob);
                metricName = 'CV';
            end

            if isempty(values)
                warning('No %s data for %s in %s. Skipped.', metricName, prob, algName);
                continue;
            end

            medVal = median(values);
            [~, medianIdx] = min(abs(values - medVal));

            % Find actual filename by scanning Data directory
            % PlatEMO may save as {Alg}_{Prob}_M{M}_D{D}_{Run}.mat
            % or as {Alg}_{Prob}_{Run}.mat — use regex to match both
            medFile = findRunFile(algDataDir, algName, prob, medianIdx);

            if isempty(medFile)
                warning('Data file for %s run %d not found in %s. Storing index only.', ...
                    prob, medianIdx, algDataDir);
            end

            fieldName = matlab.lang.makeValidName(prob);
            results.(fieldName).medianValue = medVal;
            results.(fieldName).medianIdx   = medianIdx;
            results.(fieldName).allValues   = values;
            results.(fieldName).numRuns     = numel(values);
            results.(fieldName).medianFile  = medFile;
            results.(fieldName).metric      = metricName;
            hasAny = true;
        end

        if hasAny
            outPath = fullfile(outDir, sprintf('Median_%s.mat', algName));
            save(outPath, 'results');
            fprintf('Saved: %s\n', outPath);
        else
            warning('No metric data found for %s. Skipped saving.', algName);
        end
    end

    fprintf('=== Median run extraction complete ===\n');
end

%% ==================== Helper ====================

function values = loadMapValues(baseDir, algName, mapVarName, probName)
%LOADMAPVALUES Load metric values from a containers.Map .mat file.
    values = [];

    mapPath = fullfile(baseDir, algName, [mapVarName '.mat']);
    if ~exist(mapPath, 'file')
        return;
    end

    data = load(mapPath);
    if isfield(data, mapVarName)
        map = data.(mapVarName);
    else
        fn = fieldnames(data);
        if ~isempty(fn)
            map = data.(fn{1});
        else
            return;
        end
    end

    if isa(map, 'containers.Map') && isKey(map, probName)
        values = map(probName);
    end
end

function filename = findRunFile(algDir, algName, probName, runIdx)
%FINDRUNFILE Find the actual data file for a given run index.
%   Scans the directory for files matching the algorithm-problem pattern
%   (handles both PlatEMO naming conventions), sorts them to match the
%   order used by processAlgorithmProblem, and returns the file at runIdx.
    filename = '';

    if ~exist(algDir, 'dir')
        return;
    end

    files = findMatchingFiles(algDir, algName, probName);
    if runIdx <= numel(files)
        filename = files{runIdx};
    end
end

function files = findMatchingFiles(dirPath, algName, probName)
%FINDMATCHINGFILES Scan directory for files matching algorithm-problem pattern.
%   Matches both: {Alg}_{Prob}_{Run}.mat and {Alg}_{Prob}_M{M}_D{D}_{Run}.mat
%   Returns filenames sorted to match the order used by processAlgorithmProblem.
    matFiles = dir(fullfile(dirPath, '*.mat'));

    pattern = sprintf('^%s_%s(_M\\d+_D\\d+)?_\\d+$', ...
        regexptranslate('escape', algName), ...
        regexptranslate('escape', probName));

    files = {};
    for j = 1:length(matFiles)
        [~, fname, ~] = fileparts(matFiles(j).name);
        if ~isempty(regexp(fname, pattern, 'once'))
            files{end+1} = matFiles(j).name; %#ok<AGROW>
        end
    end
    files = sort(files);
end
