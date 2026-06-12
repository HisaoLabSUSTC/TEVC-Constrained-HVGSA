runFriedmanNemenyi();

function runFriedmanNemenyi()
    % rootDir = fullfile('NHVData');
    rootDir = fullfile('AUCData');
    problem_handles = {@RWMOP1, @RWMOP2, @RWMOP3,@RWMOP4,@RWMOP5,@RWMOP6,@RWMOP7,...
            @RWMOP8,@RWMOP9,@RWMOP10,@RWMOP11,@RWMOP12,@RWMOP13,...
            @RWMOP14,@RWMOP15,@RWMOP16,@RWMOP17,@RWMOP18,@RWMOP19,...
            @RWMOP20,@RWMOP21,@RWMOP22,@RWMOP23,@RWMOP24,@RWMOP25,...
            @RWMOP26,@RWMOP27,@RWMOP28,@RWMOP29,@RWMOP30,@RWMOP31,...
            @RWMOP32,@RWMOP33,@RWMOP34,@RWMOP35,@RWMOP50};
    % problem_handles = {@RWMOP36,@RWMOP37,...
    %         @RWMOP38,@RWMOP39,@RWMOP40,@RWMOP41,@RWMOP42,@RWMOP43,...
    %         @RWMOP44,@RWMOP45,@RWMOP46,@RWMOP47,@RWMOP48,@RWMOP49};
    % mode = 'cv';
    % mode = 'hv';
    mode = 'auc';
    nRuns = 30;
    
    %% ===== 1. Friedman + Nemenyi CD Plots =====
    fprintf('\n=== Friedman + Nemenyi CD Plots ===\n');
    [avgRanks, algNames, nTests] = friedmanNemenyi(rootDir, problem_handles, nRuns, mode);
    plotCD(avgRanks, algNames, nTests, mode);
end

%% ====================== FRIEDMAN + NEMENYI ======================
function [avgRanks, algNames, nTests] = friedmanNemenyi(rootDir, problem_handles, nRuns, mode)
    algDirs = dir(rootDir);
    algDirs = algDirs([algDirs.isdir]);
    algDirs = algDirs(~ismember({algDirs.name},{'.','..'}));
    algNames = {algDirs.name};
    
    % Get problem list
    anyAlg = algNames{1};
    files = dir(fullfile(rootDir, anyAlg, 'NHV_*.mat'));
    problems = cellfun(@(f) class(f()), problem_handles, 'UniformOutput', false);
    
    nProblems = numel(problems);
    nAlgs = numel(algNames);

    if strcmp(mode, 'hv')
        finalHV = nan(nProblems*nRuns, nAlgs);
        
        % Collect all HV in the format of 
        % rows: runs*problems
        % columns: algorithms
        for a = 1:nAlgs
            run_problem_idx = 1;
            for p = 1:nProblems
                hvVals = loadFinalHV(rootDir, algNames{a}, problems{p});
                if ~isempty(hvVals)
                    finalHV(run_problem_idx:run_problem_idx+nRuns-1,a) = hvVals';
                    run_problem_idx = run_problem_idx + nRuns;
                end
            end
        end
        
        % Rank algorithms per problem (higher HV = better rank 1)
        ranks = nan(size(finalHV));
        for p = 1:nProblems*nRuns
            [~,~,rank] = unique(-finalHV(p,:)); % negative for descending
            ranks(p,:) = rank;
        end

    elseif strcmp(mode, 'cv')
        finalCV = nan(nProblems*nRuns, nAlgs);
        
        % Collect mean final HV for each algorithm/problem
        for a = 1:nAlgs
            disp(algNames{a})
            run_problem_idx = 1;
            for p = 1:nProblems
                cvVals = loadFinalCV(rootDir, algNames{a}, problems{p});
                if ~isempty(cvVals)
                    finalCV(run_problem_idx:run_problem_idx+nRuns-1,a) = cvVals';
                    run_problem_idx = run_problem_idx + nRuns;
                end
            end
        end
        
        % Rank algorithms per problem (lower CV = better rank 1)
        ranks = nan(size(finalCV));
        for p = 1:nProblems*nRuns
            [~,~,rank] = unique(finalCV(p,:)); % positive for ascending
            ranks(p,:) = rank;
        end
    elseif strcmp(mode, 'auc')
        finalAUC = nan(nProblems*nRuns, nAlgs);
        
        % Collect all HV in the format of 
        % rows: runs*problems
        % columns: algorithms
        for a = 1:nAlgs
            run_problem_idx = 1;
            for p = 1:nProblems
                AUCVals = loadFinalAUC(rootDir, algNames{a}, problems{p});
                if ~isempty(AUCVals)
                    finalAUC(run_problem_idx:run_problem_idx+nRuns-1,a) = AUCVals';
                    run_problem_idx = run_problem_idx + nRuns;
                end
            end
        end
        
        % Rank algorithms per problem (higher HV = better rank 1)
        ranks = nan(size(finalAUC));
        for p = 1:nProblems*nRuns
            [~,~,rank] = unique(-finalAUC(p,:)); % negative for descending
            ranks(p,:) = rank;
        end
    else
        warning("Not implemented.");
    end
    
    nTests = size(ranks,1);
    avgRanks = mean(ranks,1);
    
    % Friedman test
    if strcmp(mode, 'hv')
        return
        pVal = friedman(finalHV,1,'off');
    elseif strcmp(mode, 'cv')
        return
        pVal = friedman(finalCV,1,'off');
    elseif strcmp(mode, 'auc')
        return
        pVal = friedman(finalAUC,1,'off');
    end
    fprintf('Friedman test p-value = %.4g\n', pVal);
    if pVal < 0.05
        fprintf('Reject H0: not all algorithms equivalent.\n');
    else
        fprintf('Fail to reject H0: no significant difference.\n');
    end
end


function plotCD(avgRanks, algNames, nTests, mode)
    nAlgs = numel(algNames);
    alpha = 0.05;

    % --- Critical Difference ---
    qAlpha = qdist(alpha, nAlgs, 10^100);   % asymptotic
    CD = qAlpha * sqrt(nAlgs*(nAlgs+1)/(6*nTests));

    % --- Sort algorithms by rank ---
    [sortedRanks, idx] = sort(avgRanks);
    sortedNames = algNames(idx);

    % --- Plot setup ---
    xlim_small = max(-1, min(avgRanks) - 1);
    xlim_large = min(nAlgs + 1, max(avgRanks) + 1);
    if (xlim_large - xlim_small < CD)
        residue = CD - (xlim_large - xlim_small);
        xlim_large_1 = xlim_large + residue/2 + 1;
        xlim_small_1 = xlim_small - residue/2 - 1;
    end
    xlim_small_1 = xlim_small;
    xlim_large_1 = xlim_large;

    figure; hold on;
    set(gca,'YTick',[],'YLim',[-0.3 2.8], ...
        'XLim',[xlim_small_1 xlim_large_1], ...
        'Box','off'); % 'XDir','reverse'
    xlabel('Average Rank (lower is better)');

    if strcmp(mode, 'hv')
        title('CD Plot (HV)');
    elseif strcmp(mode, 'cv')
        title('CD Plot (CV)');
    elseif strcmp(mode, 'auc')
        title('CD Plot (AUC)');
    else
        warning("Not implemented.");
    end


    % --- CD bar at y=0 ---
    xStart = min(avgRanks);
    xEnd   = min(avgRanks) + CD;
    plot([xStart xEnd],[0 0],'k-','LineWidth',2);
    text((xStart+xEnd)/2,-0.05,sprintf('CD = %.2f',CD), ...
        'HorizontalAlignment','center','VerticalAlignment','top');

    % --- Algorithm points and labels ---
    for i = 1:nAlgs
        % Scatter at y=0.5
        plot(sortedRanks(i), 0.1, 'o', ...
            'MarkerSize',8,'MarkerFaceColor','b');

        % Label spread vertically to avoid clutter
        textX = sortedRanks(i);
        textY = 0.3 + 1.5*(nAlgs-i)/max(1,nAlgs-1);
        text(textX, textY, sortedNames{i}, ...
            'Rotation', 45, 'HorizontalAlignment','left', ...
            'VerticalAlignment','bottom');

        % Connector line
        plot([textX textX],[0.1 textY-0.1],'k--');
    end

    % --- Non-significant difference groups (horizontal bars) ---
    % Scan contiguous ranges of algorithms within CD
    % yBar = 2.3;  % vertical position for the bars
    % i = 1;
    % while i <= nAlgs
    %     j = i;
    %     while j < nAlgs && (sortedRanks(j+1)-sortedRanks(i) <= CD)
    %         j = j+1;
    %     end
    %     if j > i
    %         % Draw a horizontal bar from alg i to alg j
    %         x1 = sortedRanks(i);
    %         x2 = sortedRanks(j);
    %         plot([x1 x2],[yBar yBar],'k-','LineWidth',2);
    %         yBar = yBar - 0.15;  % stack bars slightly lower if overlaps
    %     end
    %     i = i+1;
    % end
end




%% ====================== HELPERS ======================
function hvVals = loadFinalHV(rootDir, alg, prob)
    files = dir(fullfile(rootDir, alg, sprintf('NHV_%s_%s_*.mat', alg, prob)));
    hvVals = [];
    for k = 1:numel(files)
        data = load(fullfile(files(k).folder, files(k).name));
        if isfield(data, 'hvData')
            hvVals(end+1) = data.hvData.HV(end);
        end
    end
end

function cvVals = loadFinalCV(rootDir, alg, prob)
    files = dir(fullfile(rootDir, alg, sprintf('NHV_%s_%s_*.mat', alg, prob)));
    cvVals = [];
    for k = 1:numel(files)
        data = load(fullfile(files(k).folder, files(k).name));
        if isfield(data, 'hvData')
            cvVals(end+1) = data.hvData.avgCV(end);
        end
    end
end

function AUCVals = loadFinalAUC(rootDir, alg, prob)
    files = dir(fullfile(rootDir, alg, sprintf('AUC_%s_%s_*.mat', alg, prob)));
    AUCVals = [];
    for k = 1:numel(files)
        data = load(fullfile(files(k).folder, files(k).name));
        AUCVals(end+1) = data.aucValue;
    end
end

function probName = parseProblemName(fname)
    parts = split(fname, '_');
    probName = parts{3}; % HV_alg_prob_M_D_run
end
