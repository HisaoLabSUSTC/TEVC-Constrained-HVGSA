function plotProblemInteractive(problemFiles, currentProblem)
    % Setup
    problemHandle = str2func(problemFiles(1).problem_name);
    problem = problemHandle('M', str2double(problemFiles(1).M), ...
                            'D', str2double(problemFiles(1).D));

    PF = problem.GetPF();
    if isnumeric(PF) && ismatrix(PF)
        ref = RefGetter(PF, 1.2);
    elseif iscell(PF)
        PF = reshape(cat(3, PF{:}), [], numel(PF));
        ref = RefGetter(PF, 1.2);
    else
        error("Error");
    end

    % Figure
    fig = figure('Name', sprintf('Hypervolume Evolution - %s', currentProblem), ...
           'Position', [100, 100, 1500, 700]);

    mainAxes = axes('Parent', fig, 'Position', [0.05, 0.1, 0.65, 0.8]);
    hold(mainAxes, 'on');

    % Process data
    problemAlgorithms = unique({problemFiles.algorithm});
    nAlgorithms = length(problemAlgorithms);
    colors = lines(nAlgorithms);

    lineHandles = gobjects(nAlgorithms, 1);
    shadeHandles = gobjects(nAlgorithms, 1);
    algorithmData = cell(nAlgorithms, 1);

    for a = 1:nAlgorithms
        % Filter and load data (same as your logic)
        currentAlgorithm = problemAlgorithms{a};
        algorithmFiles = problemFiles(strcmp({problemFiles.algorithm}, currentAlgorithm));
        allFE = {};
        allHV = {};

        for r = 1:length(algorithmFiles)
            filepath = fullfile('Data', currentAlgorithm, algorithmFiles(r).filename);
            data = load(filepath);

            if isfield(data, 'result')
                result = data.result;
                numGenerations = size(result, 1);
                FE = zeros(numGenerations, 1);
                HV = zeros(numGenerations, 1);

                for g = 1:numGenerations
                    FE(g) = result{g, 1};
                    HV(g) = stk_dominatedhv(result{g, 2}.objs, ref);
                end
                allFE{r} = FE;
                allHV{r} = HV;
            end
        end

        % Interpolate and average
        if ~isempty(allFE)
            commonFE = unique(sort(cell2mat(allFE')));
            interpolatedHV = zeros(length(commonFE), length(allHV));
            for r = 1:length(allHV)
                interpolatedHV(:, r) = interp1(allFE{r}, allHV{r}, commonFE, 'linear', 'extrap');
            end

            meanHV = mean(interpolatedHV, 2);
            stdHV = std(interpolatedHV, 0, 2);

            algorithmData{a} = struct('FE', commonFE, 'meanHV', meanHV, ...
                                      'stdHV', stdHV, 'name', currentAlgorithm);

            lineHandles(a) = plot(mainAxes, commonFE, meanHV, 'LineWidth', 2, ...
                                  'Color', colors(a,:), 'DisplayName', currentAlgorithm);
            shadeHandles(a) = fill(mainAxes, ...
                [commonFE; flipud(commonFE)], ...
                [meanHV + stdHV; flipud(meanHV - stdHV)], ...
                colors(a,:), 'FaceAlpha', 0.2, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off');
        end
    end

    % Final plot customization
    xlabel(mainAxes, 'Function Evaluations');
    ylabel(mainAxes, 'Hypervolume');
    title(mainAxes, sprintf('%s (M=%d, D=%d)', class(problem), problem.M, problem.D));
    grid(mainAxes, 'on');
    legend(mainAxes, 'show');

    % Checkbox panel
    checkboxPanel = uipanel('Parent', fig, ...
                           'Title', 'Select Algorithms', ...
                           'Position', [0.72, 0.1, 0.26, 0.8]);

    checkboxes = gobjects(nAlgorithms, 1);
    for a = 1:nAlgorithms
        yPos = 0.95 - (a-1)*(0.9/nAlgorithms);
        checkboxes(a) = uicontrol('Parent', checkboxPanel, ...
                                 'Style', 'checkbox', ...
                                 'String', problemAlgorithms{a}, ...
                                 'Value', 1, ...
                                 'Units', 'normalized', ...
                                 'Position', [0.05, yPos, 0.9, 0.8/nAlgorithms], ...
                                 'ForegroundColor', colors(a,:), ...
                                 'FontWeight', 'bold', ...
                                 'Callback', @(src,~) toggleVisibility(src, a));
    end

    % Buttons
    uicontrol('Parent', checkboxPanel, 'Style', 'pushbutton', 'String', 'Select All', ...
              'Units', 'normalized', 'Position', [0.05, 0.02, 0.4, 0.06], ...
              'Callback', @(~,~) setAllCheckboxes(1));
    uicontrol('Parent', checkboxPanel, 'Style', 'pushbutton', 'String', 'Clear All', ...
              'Units', 'normalized', 'Position', [0.55, 0.02, 0.4, 0.06], ...
              'Callback', @(~,~) setAllCheckboxes(0));

    % Cursor callback
    dcm = datacursormode(fig);
    set(dcm, 'UpdateFcn', @(~,evt) dataCursorCallback(evt));

    % Save
    savefig(fig, sprintf('HV_Interactive_%s.fig', currentProblem));
    saveas(fig, sprintf('HV_Interactive_%s.png', currentProblem));

    % --- Nested Callbacks ---
    function toggleVisibility(src, idx)
        lineHandles(idx).Visible = onOff(src.Value);
        shadeHandles(idx).Visible = onOff(src.Value);
        updateAxesLimits();
    end

    function setAllCheckboxes(val)
        for i = 1:length(checkboxes)
            checkboxes(i).Value = val;
            toggleVisibility(checkboxes(i), i);
        end
    end

    function txt = dataCursorCallback(evt)
        pos = evt.Position;
        txt = {sprintf('FE: %d', round(pos(1))), ...
               sprintf('HV: %.4f', pos(2))};
        for i = 1:numel(algorithmData)
            if isempty(algorithmData{i}), continue; end
            [~, idx] = min(abs(algorithmData{i}.FE - pos(1)));
            if abs(algorithmData{i}.meanHV(idx) - pos(2)) < 1e-3
                txt{end+1} = sprintf('Algorithm: %s', algorithmData{i}.name);
                txt{end+1} = sprintf('Std: %.4f', algorithmData{i}.stdHV(idx));
                break;
            end
        end
    end

    function updateAxesLimits()
        % Recalculate bounds
        allFE = []; allHV = [];
        for i = 1:length(lineHandles)
            if strcmp(lineHandles(i).Visible, 'on')
                d = algorithmData{i};
                allFE = [allFE; d.FE];
                allHV = [allHV; d.meanHV];
            end
        end
        if ~isempty(allFE)
            xlim(mainAxes, [min(allFE), max(allFE)]);
            ylim(mainAxes, [min(allHV)*0.95, max(allHV)*1.05]);
        end
    end

    function val = onOff(logicalVal)
        val = 'on';
        if ~logicalVal, val = 'off'; end
    end
end
