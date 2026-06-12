function VisualizeRWMOP_Backward(viz_data, problemName, varargin)
%% ===============================================================
%  RWMOP Backward Visualization (Publication-Grade)
%  ---------------------------------------------------------------
%  Plots trajectory in REVERSE chronological order so that earlier
%  (red, small) points are drawn on top of later (green, big) ones.
%  Start = red cross, Final = green circle.
%
%  Optional name-value pairs:
%     'Problem'     - PROBLEM instance. If supplied, and the decision
%                     space is 2D, a teal feasibility patch is drawn
%                     beneath the plot and a dotted black rectangle
%                     (cuboid in 3D) marks Problem.lower/upper.
%     'GridSize'    - grid resolution for the feasibility patch (default 200)
%     'TotalFE'     - scalar, total function evaluations
%     'TotalHVEval' - scalar, total hypervolume evaluations
%     'TotalTime'   - scalar, total wall-clock time in seconds
%
%  All stats arguments are shown in the legend box only when nonempty.
%  Legend entries use dummy handles so each icon renders at the correct
%  size and shape (e.g., Initial truly shows a cross) and the legend is
%  pinned outside the plot so it cannot occlude the data.
%% ===============================================================

    %% ===================== (0) ARGUMENT PARSING =====================
    p = inputParser;
    addParameter(p, 'Problem',     [], @(x) isempty(x) || isa(x, 'PROBLEM'));
    addParameter(p, 'GridSize',   200, @(x) isnumeric(x) && isscalar(x) && x > 1);
    addParameter(p, 'TotalFE',     [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
    addParameter(p, 'TotalHVEval', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
    addParameter(p, 'TotalTime',   [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
    addParameter(p, 'refp', [], @(x) isempty(x) || (isnumeric(x) && isvector(x)));
    parse(p, varargin{:});
    opts = p.Results;
    refp = opts.refp;

    %% ===================== (1) COLOR & STYLE SETTINGS =====================
    Colors.front        = [0.00, 0.00, 0.00];   % Black: reference PF/PS
    Colors.initial      = [0.80, 0.20, 0.20];   % Red:   initial population
    Colors.final        = [0.20, 0.60, 0.20];   % Green: final population
    Colors.feasible     = [0.18, 0.95, 0.85];   % Teal:  feasible area
    Colors.boundary     = [0.00, 0.00, 0.00];   % Black: decision boundary
    Colors.traj_mid     = 0.5 * (Colors.initial + Colors.final); % gradient proxy
    Colors.refp = [0.94, 0.12, 0.94]; % Purple: reference point

    Alpha.traj   = 0.75;
    Alpha.feas   = 0.05;
    Alpha.feas3d   = 0.05;

    %% Plotted-data marker sizes (scatter "SizeData" — point squared)
    MarkerSize.endpoints = 1000;      % same size for initial & final
    MarkerSize.traj_max  = 1500;      % latest gen (plotted first)
    MarkerSize.traj_min  = 50;        % earliest gen (plotted last)
    MarkerSize.feas      = 30;        % grid feasibility squares
    MarkerSize.refp = 1000;


    %% Legend-icon sizes (plot markers — points, not point-squared)
    LM.refSize  = 10;
    LM.feas     = 16;
    LM.init     = 18;
    LM.refp  = 18;
    LM.initLW   = 3;
    LM.final    = 14;
    LM.traj     = NaN; % line, no marker
    LM.trajLW   = 4;
    LM.boundLW  = 0.5;

    %% ===================== (2) DATA EXTRACTION =====================
    Populations  = viz_data.Populations;
    Hypervolumes = cell2mat(viz_data.Hypervolume);
    Initial_Pop  = Populations{1};
    Final_Pop    = Populations{end};

    [RefPF, ~, ~, RefPS] = loadReferencePF(problemName);

    % Collect mid-iteration trajectories in REVERSE chronological order
    all_decs = [];
    all_objs = [];
    if numel(Populations) >= 3
        for it = numel(Populations)-1 : -1 : 2
            all_decs = [all_decs; Populations{it}.decs]; %#ok<AGROW>
            all_objs = [all_objs; Populations{it}.objs]; %#ok<AGROW>
        end
    end

    %% Feasibility grid for 2D / 3D decision space (if Problem supplied)
    feasGrid = [];
    if ~isempty(opts.Problem) && numel(opts.Problem.lower) <= 3 ...
            && numel(opts.Problem.lower) >= 2
        feasGrid = computeFeasibilityGrid(opts.Problem, opts.GridSize);
    end

    %% Stats text rows (HV always, others only if nonempty)
    statsText = {};
    statsText{end+1} = sprintf('HV: $%.5f \\rightarrow %.5f$', ...
        Hypervolumes(1), Hypervolumes(end));
    if ~isempty(opts.TotalFE)
        statsText{end+1} = sprintf('Total FE: %d', round(opts.TotalFE));
    end
    if ~isempty(opts.TotalHVEval)
        statsText{end+1} = sprintf('Total HV Evals: %d', round(opts.TotalHVEval));
    end
    if ~isempty(opts.TotalTime)
        statsText{end+1} = sprintf('Total Time: %.3f s', opts.TotalTime);
    end

    %% ===================== (3) DECISION SPACE FIGURE =====================
    if size(RefPS, 2) >= 2
        nDec = min(size(RefPS, 2), 3);
        is3D = nDec >= 3;

        if ishandle(1) && strcmp(get(1, 'Type'), 'figure')
            fig1 = figure(1);
        else
            fig1 = PreprocessProductionImage(0.45, 0.5, 8.8);
        end

        ax1 = fig1.CurrentAxes;
        cla(ax1, 'reset'); hold(ax1, 'on'); grid(ax1, 'on'); box(ax1, 'on'); axis(ax1, 'tight');

        %% Feasibility patch — drawn first so it sits behind everything
        h_feas_plot = gobjects(1,1);
        if ~isempty(feasGrid)
            feas_x = feasGrid.G1(feasGrid.feasMask);
            feas_y = feasGrid.G2(feasGrid.feasMask);
            if is3D && isfield(feasGrid, 'G3')
                feas_z = feasGrid.G3(feasGrid.feasMask);
                h_feas_plot = scatter3(ax1, feas_x, feas_y, feas_z, ...
                    MarkerSize.feas, Colors.feasible, 's', 'filled', ...
                    'MarkerFaceAlpha', Alpha.feas3d, ...
                    'MarkerEdgeColor', 'none');
            elseif ~is3D
                h_feas_plot = scatter(ax1, feas_x, feas_y, ...
                    MarkerSize.feas, Colors.feasible, 's', 'filled', ...
                    'MarkerFaceAlpha', Alpha.feas, ...
                    'MarkerEdgeColor', 'none');
            end
        end

        %% Reference PS
        if is3D
            h_refPS = scatter3(ax1, RefPS(:,1), RefPS(:,2), RefPS(:,3), ...
                5, Colors.front, 'filled', 'MarkerFaceAlpha', 0.3);
        else
            h_refPS = scatter(ax1, RefPS(:,1), RefPS(:,2), ...
                5, Colors.front, 'filled', 'MarkerFaceAlpha', 0.3);
        end

        %% Trajectories (green/big first, red/small last)
        h_traj_dec = gobjects(1,1);
        if ~isempty(all_decs)
            nPts = size(all_decs, 1);
            t = linspace(0, 1, nPts)';
            C_traj = (1 - t) .* Colors.final + t .* Colors.initial;
            S_traj = (MarkerSize.traj_max + t .* (MarkerSize.traj_min - MarkerSize.traj_max)) .* 2;

            if is3D
                h_traj_dec = scatter3(ax1, all_decs(:,1), all_decs(:,2), all_decs(:,3), ...
                    S_traj, C_traj, 'Marker', '.', ...
                    'MarkerFaceAlpha', Alpha.traj, 'MarkerEdgeAlpha', Alpha.traj);
            else
                h_traj_dec = scatter(ax1, all_decs(:,1), all_decs(:,2), ...
                    S_traj, C_traj, 'Marker', '.', ...
                    'MarkerFaceAlpha', Alpha.traj, 'MarkerEdgeAlpha', Alpha.traj);
            end
        end

        %% Final population (green circle)
        FPD = Final_Pop.decs;
        if is3D
            h_final_dec = scatter3(ax1, FPD(:,1), FPD(:,2), FPD(:,3), ...
                'SizeData', MarkerSize.endpoints, 'CData', Colors.final, ...
                'Marker', 'o', 'MarkerFaceColor', 'flat', 'MarkerEdgeColor', 'none');
        else
            h_final_dec = scatter(ax1, FPD(:,1), FPD(:,2), ...
                'SizeData', MarkerSize.endpoints, 'CData', Colors.final, ...
                'Marker', 'o', 'MarkerFaceColor', 'flat', 'MarkerEdgeColor', 'none');
        end

        %% Initial population (red cross)
        IPD = Initial_Pop.decs;
        if is3D
            h_init_dec = scatter3(ax1, IPD(:,1), IPD(:,2), IPD(:,3), ...
                'SizeData', MarkerSize.endpoints, 'CData', Colors.initial, ...
                'Marker', 'x', 'LineWidth', 6.0, 'MarkerEdgeColor', 'flat');
        else
            h_init_dec = scatter(ax1, IPD(:,1), IPD(:,2), ...
                'SizeData', MarkerSize.endpoints, 'CData', Colors.initial, ...
                'Marker', 'x', 'LineWidth', 6.0, 'MarkerEdgeColor', 'flat');
        end

        %% Decision boundary (black dotted rectangle / cuboid)
        h_bound_plot = gobjects(1,1);
        if ~isempty(opts.Problem)
            h_bound_plot = plotDecisionBoundary(ax1, opts.Problem, is3D, ...
                Colors.boundary, LM.boundLW);
        end

        %% Z-ordering: endpoints on top; trajectory, refPS, feas below
        if isgraphics(h_feas_plot), uistack(h_feas_plot, 'bottom'); end
        uistack(h_refPS, 'bottom');
        if isgraphics(h_traj_dec), uistack(h_traj_dec, 'bottom'); end
        uistack(h_final_dec, 'top');
        uistack(h_init_dec, 'top');

        %% Axis labels (preserve original exponent handling)
        xexp = double(ax1.XAxis.Exponent);
        yexp = double(ax1.YAxis.Exponent);
        zexp = double(ax1.ZAxis.Exponent);

        if xexp ~= 0
            xlabel(ax1, sprintf('$x_1 (10^{%d})$', xexp), 'Interpreter', 'latex');
        else
            xlabel(ax1, '$x_1$', 'Interpreter', 'latex');
        end
        if yexp ~= 0
            ylabel(ax1, sprintf('$x_2 (10^{%d})$', yexp), 'Interpreter', 'latex');
        else
            ylabel(ax1, '$x_2$', 'Interpreter', 'latex');
        end

        if is3D
            if zexp ~= 0
                zlabel(ax1, sprintf('$x_3 (10^{%d})$', zexp), 'Interpreter', 'latex');
            else
                zlabel(ax1, '$x_3$', 'Interpreter', 'latex');
            end
            view(ax1, -37.5, 30);
        end

        ax1.XAxis.Exponent = 0;
        ax1.YAxis.Exponent = 0;
        xticklabels(string(xticks / 10^xexp));
        yticklabels(string(yticks / 10^yexp));
        if is3D
            ax1.ZAxis.Exponent = 0;
            zticklabels(string(zticks / 10^zexp));
        end

        %% Shortened title (HV info moves to the legend)
        title(ax1, sprintf('%s Decision Space', problemName), 'Interpreter', 'latex');

        %% Rich legend — dummy handles + pinned outside the plot
        buildRichLegend(ax1, ...
            'ReferenceLabel',    sprintf('Reference PS/PF (%d pts)', size(RefPS,1)), ...
            'IncludeTrajectory', ~isempty(all_decs), ...
            'IncludeFeasibility', isgraphics(h_feas_plot), ...
            'IncludeBoundary',   isgraphics(h_bound_plot), ...
            'IterCount',         numel(Populations)-1, ...
            'Colors',            Colors, ...
            'LM',                LM, ...
            'Stats',             statsText);

        %% Axis limits
        data_dec = [IPD(:,1:nDec); FPD(:,1:nDec); all_decs(:,1:nDec); RefPS(:,1:nDec)];
        if ~isempty(opts.Problem)
            data_dec = [data_dec; opts.Problem.lower(1:nDec); opts.Problem.upper(1:nDec)];
        end
        setTightAxes(ax1, data_dec);

        % imgDir = './ProduceImage/images';
        % if ~exist(imgDir, 'dir'), mkdir(imgDir); end
        % 
        % filename = sprintf('%s_Decision_BW.png', problemName);
        % exportgraphics(gcf, fullfile(imgDir, filename), 'Resolution', 300);
        % % exportgraphics(gcf, filename, 'ContentType', 'vector');
        % % close(gcf);
    end

    %% ===================== (4) OBJECTIVE SPACE FIGURE =====================
    nObj = min(size(RefPF, 2), 3);
    is3DObj = nObj >= 3;

    if ishandle(2) && strcmp(get(2, 'Type'), 'figure')
        fig2 = figure(2);
    else
        fig2 = PreprocessProductionImage(0.45, 0.5, 8.8);
    end

    ax2 = fig2.CurrentAxes;
    cla(ax2, 'reset'); hold(ax2, 'on'); grid(ax2, 'on'); box(ax2, 'on'); axis(ax2, 'tight');

    %% Reference PF
    if is3DObj
        h_refPF = scatter3(ax2, RefPF(:,1), RefPF(:,2), RefPF(:,3), ...
            5, Colors.front, 'filled', 'MarkerFaceAlpha', 0.3);

        h_refP = scatter3(ax2, refp(:,1), refp(:,2), refp(:,3), ...
            MarkerSize.refp, Colors.refp, 'filled', 'pentagram');
    else
        h_refPF = scatter(ax2, RefPF(:,1), RefPF(:,2), ...
            5, Colors.front, 'filled', 'MarkerFaceAlpha', 0.3);

        h_refP = scatter(ax2, refp(:,1), refp(:,2), ...
            MarkerSize.refp, Colors.refp, 'filled', 'pentagram');
    end

    %% Trajectories
    h_traj_obj = gobjects(1,1);
    if ~isempty(all_objs)
        nPts = size(all_objs, 1);
        t = linspace(0, 1, nPts)';
        C_traj = (1 - t) .* Colors.final + t .* Colors.initial;
        S_traj = MarkerSize.traj_max + t .* (MarkerSize.traj_min - MarkerSize.traj_max);

        if is3DObj
            h_traj_obj = scatter3(ax2, all_objs(:,1), all_objs(:,2), all_objs(:,3), ...
                S_traj, C_traj, 'Marker', '.', ...
                'MarkerFaceAlpha', Alpha.traj, 'MarkerEdgeAlpha', Alpha.traj);
        else
            h_traj_obj = scatter(ax2, all_objs(:,1), all_objs(:,2), ...
                S_traj, C_traj, 'Marker', '.', ...
                'MarkerFaceAlpha', Alpha.traj, 'MarkerEdgeAlpha', Alpha.traj);
        end
    end

    %% Final population
    FPO = Final_Pop.objs;
    if is3DObj
        h_final_obj = scatter3(ax2, FPO(:,1), FPO(:,2), FPO(:,3), ...
            'SizeData', MarkerSize.endpoints, 'CData', Colors.final, ...
            'Marker', 'o', 'MarkerFaceColor', 'flat', 'MarkerEdgeColor', 'none');
    else
        h_final_obj = scatter(ax2, FPO(:,1), FPO(:,2), ...
            'SizeData', MarkerSize.endpoints, 'CData', Colors.final, ...
            'Marker', 'o', 'MarkerFaceColor', 'flat', 'MarkerEdgeColor', 'none');
    end

    %% Initial population
    IPO = Initial_Pop.objs;
    if is3DObj
        h_init_obj = scatter3(ax2, IPO(:,1), IPO(:,2), IPO(:,3), ...
            'SizeData', MarkerSize.endpoints, 'CData', Colors.initial, ...
            'Marker', 'x', 'LineWidth', 6.0, 'MarkerEdgeColor', 'flat');
    else
        h_init_obj = scatter(ax2, IPO(:,1), IPO(:,2), ...
            'SizeData', MarkerSize.endpoints, 'CData', Colors.initial, ...
            'Marker', 'x', 'LineWidth', 6.0, 'MarkerEdgeColor', 'flat');
    end

    %% Z-ordering
    uistack(h_refPF, 'bottom');
    if isgraphics(h_traj_obj), uistack(h_traj_obj, 'bottom'); end
    uistack(h_final_obj, 'top');
    uistack(h_init_obj, 'top');

    %% Axis labels
    xexp = double(ax2.XAxis.Exponent);
    yexp = double(ax2.YAxis.Exponent);
    zexp = double(ax2.ZAxis.Exponent);

    if xexp ~= 0
        xlabel(ax2, sprintf('$f_1 (10^{%d})$', xexp), 'Interpreter', 'latex');
    else
        xlabel(ax2, '$f_1$', 'Interpreter', 'latex');
    end
    if yexp ~= 0
        ylabel(ax2, sprintf('$f_2 (10^{%d})$', yexp), 'Interpreter', 'latex');
    else
        ylabel(ax2, '$f_2$', 'Interpreter', 'latex');
    end

    if is3DObj
        if zexp ~= 0
            zlabel(ax2, sprintf('$f_3 (10^{%d})$', zexp), 'Interpreter', 'latex');
        else
            zlabel(ax2, '$f_3$', 'Interpreter', 'latex');
        end
        view(ax2, -37.5, 30);
    end

    ax2.XAxis.Exponent = 0;
    ax2.YAxis.Exponent = 0;
    xticklabels(string(xticks / 10^xexp));
    yticklabels(string(yticks / 10^yexp));
    if is3DObj
        ax2.ZAxis.Exponent = 0;
        zticklabels(string(zticks / 10^zexp));
    end

    %% Shortened title
    title(ax2, sprintf('%s Objective Space', problemName), 'Interpreter', 'latex');

    % %% Rich legend (no feasibility / boundary in objective space)
    % buildRichLegend(ax2, ...
    %     'ReferenceLabel',    sprintf('Reference PF (%d pts)', size(RefPF,1)), ...
    %     'IncludeTrajectory', ~isempty(all_objs), ...
    %     'IncludeFeasibility', false, ...
    %     'IncludeBoundary',   false, ...
    %     'IterCount',         numel(Populations)-1, ...
    %     'Colors',            Colors, ...
    %     'LM',                LM, ...
    %     'Stats',             statsText);

    set(ax2, 'Position', ax1.Position)

    %% Axis limits
    data_obj = [IPO(:,1:nObj); FPO(:,1:nObj); all_objs(:,1:nObj); RefPF(:,1:nObj); refp];
    setTightAxes(ax2, data_obj);

    % imgDir = './ProduceImage/images';
    % if ~exist(imgDir, 'dir'), mkdir(imgDir); end
    % % print(fullfile(imgDir, sprintf('%s_Objective_BW.eps', problemName)), '-depsc');
    % filename = sprintf('%s_Objective_BW.png', problemName);
    % exportgraphics(gcf, fullfile(imgDir, filename), 'Resolution', 300);
    % % exportgraphics(gcf, filename, 'ContentType', 'vector');
    % % close(gcf);



    %% ===================== (5) SUMMARY (Console) =====================
    fprintf('\n=== Optimization Summary ===\n');
    fprintf('Problem: %s\n', problemName);
    fprintf('Total Iterations: %d\n', numel(Populations)-1);
    fprintf('Initial HV: %.5f\n', Hypervolumes(1));
    fprintf('Final HV: %.5f\n', Hypervolumes(end));
    fprintf('HV Improvement: %.5f (%.2f%%)\n', ...
        Hypervolumes(end) - Hypervolumes(1), ...
        100 * (Hypervolumes(end) - Hypervolumes(1)) / max(Hypervolumes(1), eps));
end

%% ===================== (HELPERS) =====================
function feasGrid = computeFeasibilityGrid(Problem, gridSize)
%COMPUTEFEASIBILITYGRID Flag feasible points on a 2D or 3D decision-space grid.
%   gridSize is the requested per-axis resolution. For 3D it is capped so
%   that the total point count stays in the same ballpark as the 2D default
%   (otherwise a 200^3 sample would be 8M evaluations).
    L = Problem.lower;
    U = Problem.upper;
    nDim = numel(L);

    if nDim == 2
        x1 = linspace(L(1), U(1), gridSize);
        x2 = linspace(L(2), U(2), gridSize);
        [G1, G2] = meshgrid(x1, x2);
        gridPts = [G1(:), G2(:)];
    elseif nDim == 3
        gs3 = min(gridSize, 60);
        x1 = linspace(L(1), U(1), gs3);
        x2 = linspace(L(2), U(2), gs3);
        x3 = linspace(L(3), U(3), gs3);
        [G1, G2, G3] = ndgrid(x1, x2, x3);
        gridPts = [G1(:), G2(:), G3(:)];
    else
        feasGrid = [];
        return;
    end

    sols = Problem.Evaluation(gridPts);
    cons = sols.cons;
    if isempty(cons)
        totalCV = zeros(size(gridPts, 1), 1);
    else
        totalCV = sum(max(0, cons), 2);
    end

    feasGrid.G1 = G1;
    feasGrid.G2 = G2;
    if nDim == 3
        feasGrid.G3 = G3;
    end
    feasGrid.feasMask = reshape(totalCV <= 0, size(G1));
end

function h = plotDecisionBoundary(ax, Problem, is3D, color, lw)
%PLOTDECISIONBOUNDARY Draw the decision-space box as a dotted line.
    L = Problem.lower;
    U = Problem.upper;
    if is3D && numel(L) >= 3
        corners = [L(1) L(2) L(3); U(1) L(2) L(3); U(1) U(2) L(3); L(1) U(2) L(3);
                   L(1) L(2) U(3); U(1) L(2) U(3); U(1) U(2) U(3); L(1) U(2) U(3)];
        edges = [1 2; 2 3; 3 4; 4 1; 5 6; 6 7; 7 8; 8 5; 1 5; 2 6; 3 7; 4 8];
        h = gobjects(1,1);
        for k = 1:size(edges,1)
            p = corners(edges(k,:), :);
            hk = line(ax, p(:,1), p(:,2), p(:,3), ...
                'Color', color, 'LineStyle', '--', 'LineWidth', lw);
            if k == 1, h = hk; end
        end
    elseif numel(L) >= 2
        x = [L(1), U(1), U(1), L(1), L(1)];
        y = [L(2), L(2), U(2), U(2), L(2)];
        h = plot(ax, x, y, '--', 'Color', color, 'LineWidth', lw);
    else
        h = gobjects(1,1);
    end
end

function buildRichLegend(ax, varargin)
%BUILDRICHLEGEND Create legend using dummy handles for consistent styling.
    p = inputParser;
    addParameter(p, 'ReferenceLabel',    'Reference');
    addParameter(p, 'IncludeTrajectory', true);
    addParameter(p, 'IncludeFeasibility', false);
    addParameter(p, 'IncludeBoundary',   false);
    addParameter(p, 'IterCount',         0);
    addParameter(p, 'Colors',            struct());
    addParameter(p, 'LM',                struct());
    addParameter(p, 'Stats',             {});
    parse(p, varargin{:});
    A = p.Results;
    C = A.Colors; LM = A.LM;

    handles = gobjects(0);

    % Reference PS/PF icon
    handles(end+1) = plot(ax, NaN, NaN, ...
        'Marker', 'o', 'MarkerFaceColor', C.front, 'MarkerEdgeColor', 'none', ...
        'MarkerSize', LM.refSize, 'LineStyle', 'none', ...
        'DisplayName', A.ReferenceLabel); %#ok<AGROW>

    % Reference PS/PF icon
    handles(end+1) = plot(ax, NaN, NaN, ...
        'Marker', 'pentagram', 'MarkerFaceColor', C.refp, 'MarkerEdgeColor', C.refp, ...
        'MarkerSize', LM.refp, 'LineStyle', 'none', ...
        'DisplayName', 'Reference Point'); %#ok<AGROW>

    if A.IncludeFeasibility
        handles(end+1) = plot(ax, NaN, NaN, ...
            'Marker', 's', 'MarkerFaceColor', C.feasible, 'MarkerEdgeColor', 'none', ...
            'MarkerSize', LM.feas, 'LineStyle', 'none', ...
            'DisplayName', 'Feasible Area'); %#ok<AGROW>
    end

    if A.IncludeBoundary
        handles(end+1) = plot(ax, NaN, NaN, ...
            'LineStyle', '--', 'Color', C.boundary, 'LineWidth', LM.boundLW, ...
            'Marker', 'none', ...
            'DisplayName', 'Decision Boundary'); %#ok<AGROW>
    end

    % Initial — red cross (not diamond)
    handles(end+1) = plot(ax, NaN, NaN, ...
        'Marker', 'x', 'MarkerEdgeColor', C.initial, ...
        'MarkerSize', LM.init, 'LineWidth', LM.initLW, 'LineStyle', 'none', ...
        'DisplayName', 'Initial (iter 0)'); %#ok<AGROW>

    % Final — green circle
    handles(end+1) = plot(ax, NaN, NaN, ...
        'Marker', 'o', 'MarkerFaceColor', C.final, 'MarkerEdgeColor', 'none', ...
        'MarkerSize', LM.final, 'LineStyle', 'none', ...
        'DisplayName', sprintf('Final (iter %d)', A.IterCount)); %#ok<AGROW>

    if A.IncludeTrajectory
        handles(end+1) = plot(ax, NaN, NaN, ...
            'LineStyle', '-', 'Color', C.traj_mid, 'LineWidth', LM.trajLW, ...
            'Marker', 'none', ...
            'DisplayName', 'Trajectory (red $\to$ green)'); %#ok<AGROW>
    end

    % Stats rows — text-only entries (blank icon area)
    for k = 1:numel(A.Stats)
        handles(end+1) = plot(ax, NaN, NaN, ...
            'LineStyle', 'none', 'Marker', 'none', ...
            'DisplayName', A.Stats{k}); %#ok<AGROW>
    end

    leg = legend(ax, handles, 'Interpreter', 'latex', 'Location', 'eastoutside');
    leg.Box = 'on';
end

function setTightAxes(ax, data)
    if isempty(data) || size(data,2) < 2
        return;
    end
    xmin = min(data(:,1)); xmax = max(data(:,1));
    ymin = min(data(:,2)); ymax = max(data(:,2));
    if ~isfinite(xmin) || ~isfinite(xmax) || ~isfinite(ymin) || ~isfinite(ymax)
        return;
    end
    dx = xmax - xmin; dy = ymax - ymin;
    if dx <= 0, dx = 1; end
    if dy <= 0, dy = 1; end
    pad = 0.05;
    xlim(ax, [xmin - pad*dx, xmax + pad*dx]);
    ylim(ax, [ymin - pad*dy, ymax + pad*dy]);
    if size(data, 2) >= 3
        zmin = min(data(:,3)); zmax = max(data(:,3));
        if isfinite(zmin) && isfinite(zmax)
            dz = zmax - zmin;
            if dz <= 0, dz = 1; end
            zlim(ax, [zmin - pad*dz, zmax + pad*dz]);
        end
    end
end
