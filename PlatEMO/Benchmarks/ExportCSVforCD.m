% rootDir = fullfile('NHVData');
rootDir = fullfile('AUCData');

% problem_handles = {@RWMOP1, @RWMOP2, @RWMOP3,@RWMOP4,@RWMOP5,@RWMOP6,@RWMOP7,...
%         @RWMOP8,@RWMOP9,@RWMOP10,@RWMOP11,@RWMOP12,@RWMOP13,...
%         @RWMOP14,@RWMOP15,@RWMOP16,@RWMOP17,@RWMOP18,@RWMOP19,...
%         @RWMOP20,@RWMOP21,@RWMOP22,@RWMOP23,@RWMOP24,@RWMOP25,...
%         @RWMOP26,@RWMOP27,@RWMOP28,@RWMOP29,@RWMOP30,@RWMOP31,...
%         @RWMOP32,@RWMOP33,@RWMOP34,@RWMOP35,@RWMOP50};
problem_handles = {@RWMOP36,@RWMOP37,...
        @RWMOP38,@RWMOP39,@RWMOP40,@RWMOP41,@RWMOP42,@RWMOP43,...
        @RWMOP44,@RWMOP45,@RWMOP46,@RWMOP47,@RWMOP48,@RWMOP49};

% mode = 'cv';
% mode = 'hv';
mode = 'auc';
    
nRuns     = 30;

export_CSV_for_CD(rootDir, problem_handles, mode, nRuns, 'cd_cv_auc.csv');

function export_CSV_for_CD(rootDir, problem_handles, mode, nRuns, outCSV)
% EXPORT_CSV_FOR_CD  Export MOEA results into a Python CD-diagram-friendly CSV.
% Usage:
%   export_CSV_for_CD(rootDir, problem_handles, mode, nRuns, outCSV)
%
% Inputs:
%   rootDir          - char/string, e.g., 'NHVData' or 'AUCData'
%   problem_handles  - cell array of @RWMOP* function handles
%   mode             - 'hv' | 'cv' | 'auc'
%   nRuns            - integer, e.g., 30
%   outCSV           - char/string output file name, e.g., 'cd_auc.csv'
%
% Output CSV schema:
%   classifier_name,dataset_name,metric
%   <ALG>,<PROBLEM>_R<run>,<value>

    arguments
        rootDir (1,:) char
        problem_handles (1,:) cell
        mode (1,:) char {mustBeMember(mode, {'hv','cv','auc'})}
        nRuns (1,1) double {mustBeInteger, mustBePositive}
        outCSV (1,:) char
    end

    % --- Scan algorithms (subfolders of rootDir) ---
    algDirs = dir(rootDir);
    algDirs = algDirs([algDirs.isdir]);
    algDirs = algDirs(~ismember({algDirs.name},{'.','..'}));
    algNames = {algDirs.name};

    % --- Problem names from handles ---
    problems = cellfun(@(f) class(f()), problem_handles, 'UniformOutput', false);

    % --- Open CSV ---
    fid = fopen(outCSV, 'w');
    if fid == -1
        error('Could not open output CSV: %s', outCSV);
    end
    fprintf(fid, 'classifier_name,dataset_name,metric\n');

    % --- Export loop ---
    for a = 1:numel(algNames)
        alg = algNames{a};
        disp(alg);

        for p = 1:numel(problems)
            prob = problems{p};

            switch mode
                case 'hv'
                    vals = loadFinalHV(rootDir, alg, prob, nRuns);
                case 'cv'
                    vals = loadFinalCV(rootDir, alg, prob, nRuns);
                case 'auc'
                    vals = loadFinalAUC(rootDir, alg, prob, nRuns);
            end

            if all(isnan(vals))
                warning('No data found: alg=%s, prob=%s', alg, prob);
                continue;
            end

            for r = 1:nRuns
                if ~isnan(vals(r))
                    dsMerged = sprintf('%s_R%d', prob, r);
                    fprintf(fid, '%s,%s,%.15g\n', alg, dsMerged, vals(r));
                else
                    % Missing specific run file
                    warning('Missing run %d: alg=%s, prob=%s', r, alg, prob);
                end
            end
        end
    end

    fclose(fid);
end

% ====================== HELPERS ======================

function hvVals = loadFinalHV(rootDir, alg, prob, nRuns)
% Returns 1xnRuns vector with HV(end) per run (NaN if missing)
    pattern = fullfile(rootDir, alg, sprintf('NHV_%s_%s_*.mat', alg, prob));
    files = dir(pattern);
    hvVals = nan(1, nRuns);
    for k = 1:numel(files)
        runIdx = parseRunIndex(files(k).name);
        if isnan(runIdx) || runIdx < 1 || runIdx > numel(hvVals)
            % If run index not recoverable, place into first available NaN slot
            runIdx = firstAvailableIndex(hvVals);
            if isnan(runIdx), continue; end
        end
        data = load(fullfile(files(k).folder, files(k).name));
        if isfield(data, 'hvData') && isfield(data.hvData, 'HV') && ~isempty(data.hvData.HV)
            hvVals(runIdx) = data.hvData.HV(end);
        end
    end
end

function cvVals = loadFinalCV(rootDir, alg, prob, nRuns)
% Returns 1xnRuns vector with avgCV(end) per run (NaN if missing)
    pattern = fullfile(rootDir, alg, sprintf('NHV_%s_%s_*.mat', alg, prob));
    files = dir(pattern);
    cvVals = nan(1, nRuns);
    for k = 1:numel(files)
        runIdx = parseRunIndex(files(k).name);
        if isnan(runIdx) || runIdx < 1 || runIdx > numel(cvVals)
            runIdx = firstAvailableIndex(cvVals);
            if isnan(runIdx), continue; end
        end
        data = load(fullfile(files(k).folder, files(k).name));
        if isfield(data, 'hvData') && isfield(data.hvData, 'avgCV') && ~isempty(data.hvData.avgCV)
            cvVals(runIdx) = data.hvData.avgCV(end);
        end
    end
end

function aucVals = loadFinalAUC(rootDir, alg, prob, nRuns)
% Returns 1xnRuns vector with aucValue per run (NaN if missing)
    pattern = fullfile(rootDir, alg, sprintf('AUC_%s_%s_*.mat', alg, prob));
    files = dir(pattern);
    aucVals = nan(1, nRuns);
    for k = 1:numel(files)
        runIdx = parseRunIndex(files(k).name);
        if isnan(runIdx) || runIdx < 1 || runIdx > numel(aucVals)
            runIdx = firstAvailableIndex(aucVals);
            if isnan(runIdx), continue; end
        end
        data = load(fullfile(files(k).folder, files(k).name));
        if isfield(data, 'aucValue')
            aucVals(runIdx) = data.aucValue;
        end
    end
end

function idx = parseRunIndex(fname)
% Attempt to parse trailing run index from filename, e.g. *_<run>.mat
% Falls back to NaN if not found.
    idx = NaN;
    % Try strict: last _<digits>.mat
    tok = regexp(fname, '_(\d+)\.mat$', 'tokens', 'once');
    if ~isempty(tok)
        idx = str2double(tok{1});
        if ~isfinite(idx), idx = NaN; end
        return;
    end
    % Try loose: last _<digits> (without .mat guard)
    tok = regexp(fname, '_(\d+)$', 'tokens', 'once');
    if ~isempty(tok)
        idx = str2double(tok{1});
        if ~isfinite(idx), idx = NaN; end
    end
end

function pos = firstAvailableIndex(vec)
% Return first index where vec is NaN, else NaN
    nanMask = isnan(vec);
    if any(nanMask)
        pos = find(nanMask, 1, 'first');
    else
        pos = NaN;
    end
end

