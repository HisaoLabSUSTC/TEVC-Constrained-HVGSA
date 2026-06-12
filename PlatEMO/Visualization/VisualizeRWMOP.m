function VisualizeRWMOP(viz_data, problemName)
%% ===============================================================
%  RWMOP Visualization (Publication-Grade; Decision & Objective Spaces)
%  ---------------------------------------------------------------
%  Visualizes the trajectory of HVGSA on a real-world MOP.
%  Reference PF/PS are loaded from Info/ReferencePF/RefPF-{name}.mat.
%  Supports 2- or 3-objective problems with 2 or 3 decision variables.
%  ---------------------------------------------------------------

    fig_width = 1200;
    fig_height = 1200;

    %% ===================== (1) COLOR & STYLE SETTINGS =====================
    Colors.front         = [0.00, 0.00, 0.00];   % Black: reference PF/PS
    Colors.initial       = [0.80, 0.20, 0.20];   % Red: initial population
    Colors.final         = [0.20, 0.60, 0.20];   % Green: final population
    Colors.trajectory    = [0.55, 0.20, 0.55];   % Purple: trajectories

    Alpha.traj   = 0.35;
    Alpha.init   = 0.95;
    Alpha.final  = 0.95;

    MarkerSize.initial    = 300;
    MarkerSize.final      = 300;
    MarkerSize.trajectory = 100;

    LW.front  = 1.5;
    LW.edge   = 1.2;

    loc = "southeast";

    %% ===================== (2) DATA EXTRACTION =====================
    Populations  = viz_data.Populations;
    Hypervolumes = cell2mat(viz_data.Hypervolume);
    Initial_Pop  = Populations{1};
    Final_Pop    = Populations{end};

    % Load reference PF and PS from file
    [RefPF, ~, ~, RefPS] = loadReferencePF(problemName);

    % Collect mid-iteration trajectories (exclude first/last)
    all_decs = [];
    all_objs = [];
    if numel(Populations) >= 3
        for it = 2:numel(Populations)-1
            all_decs = [all_decs; Populations{it}.decs]; %#ok<AGROW>
            all_objs = [all_objs; Populations{it}.objs]; %#ok<AGROW>
        end
    end

    %% ===================== (3) DECISION SPACE FIGURE =====================
    if size(RefPS, 2) >= 2
        nDec = min(size(RefPS, 2), 3);
        is3D = nDec >= 3;

        if ishandle(1) && strcmp(get(1, 'Type'), 'figure')
            fig1 = figure(1);
        else
            fig1 = figure('Position', [100, 100, fig_width, fig_height], ...
                      'Color', 'w', ...
                      'Name', sprintf('%s - Decision Space', problemName));
        end

        ax1 = axes('Parent', fig1, 'Position', [0.10, 0.15, 0.85, 0.75]);
        cla(ax1, 'reset'); hold(ax1, 'on'); grid(ax1, 'on'); box(ax1, 'on'); axis(ax1, 'tight');

        %% Reference PS (scatter — numerically computed, not analytical)
        if is3D
            h_refPS = scatter3(ax1, RefPS(:,1), RefPS(:,2), RefPS(:,3), ...
                20, Colors.front, 'filled', ...
                'MarkerFaceAlpha', 0.3, ...
                'DisplayName', sprintf('Reference PS (%d pts)', size(RefPS,1)));
        else
            h_refPS = scatter(ax1, RefPS(:,1), RefPS(:,2), ...
                20, Colors.front, 'filled', ...
                'MarkerFaceAlpha', 0.3, ...
                'DisplayName', sprintf('Reference PS (%d pts)', size(RefPS,1)));
        end

        %% Trajectories in decision space
        h_traj_dec = gobjects(1,1);
        if ~isempty(all_decs)
            nPts = size(all_decs, 1);
            t = linspace(0, 1, nPts)';
            C_traj = (1 - t) .* Colors.initial + t .* Colors.final;

            if is3D
                h_traj_dec = scatter3(ax1, ...
                    all_decs(:,1), all_decs(:,2), all_decs(:,3), ...
                    MarkerSize.trajectory, C_traj, ...
                    'Marker', '.', ...
                    'MarkerFaceAlpha', Alpha.traj, ...
                    'MarkerEdgeAlpha', Alpha.traj, ...
                    'DisplayName', 'Trajectory (red $\to$ green)');
            else
                h_traj_dec = scatter(ax1, ...
                    all_decs(:,1), all_decs(:,2), ...
                    MarkerSize.trajectory, C_traj, ...
                    'Marker', '.', ...
                    'MarkerFaceAlpha', Alpha.traj, ...
                    'MarkerEdgeAlpha', Alpha.traj, ...
                    'DisplayName', 'Trajectory (red $\to$ green)');
            end
        end

        %% Initial population (decision)
        IPD = Initial_Pop.decs;
        if is3D
            h_init_dec = scatter3(ax1, ...
                IPD(:,1), IPD(:,2), IPD(:,3), ...
                'SizeData', MarkerSize.initial, ...
                'CData', Colors.initial, ...
                'Marker', 'o', ...
                'MarkerFaceColor', 'flat', ...
                'MarkerEdgeColor', 'none', ...
                'DisplayName', 'Initial (iter 0)');
        else
            h_init_dec = scatter(ax1, ...
                IPD(:,1), IPD(:,2), ...
                'SizeData', MarkerSize.initial, ...
                'CData', Colors.initial, ...
                'Marker', 'o', ...
                'MarkerFaceColor', 'flat', ...
                'MarkerEdgeColor', 'none', ...
                'DisplayName', 'Initial (iter 0)');
        end

        %% Final population (decision)
        FPD = Final_Pop.decs;
        if is3D
            h_final_dec = scatter3(ax1, ...
                FPD(:,1), FPD(:,2), FPD(:,3), ...
                'SizeData', MarkerSize.final, ...
                'CData', Colors.final, ...
                'Marker', '^', ...
                'MarkerFaceColor', 'flat', ...
                'MarkerEdgeColor', 'none', ...
                'DisplayName', sprintf('Final (iter %d)', numel(Populations)-1));
        else
            h_final_dec = scatter(ax1, ...
                FPD(:,1), FPD(:,2), ...
                'SizeData', MarkerSize.final, ...
                'CData', Colors.final, ...
                'Marker', '^', ...
                'MarkerFaceColor', 'flat', ...
                'MarkerEdgeColor', 'none', ...
                'DisplayName', sprintf('Final (iter %d)', numel(Populations)-1));
        end

        %% Z-ordering
        uistack(h_refPS, 'bottom');
        uistack(h_traj_dec, 'top');
        uistack(h_init_dec, 'top');
        uistack(h_final_dec, 'top');

        %% Labels
        xlabel(ax1, '$x_1$', 'Interpreter', 'latex');
        ylabel(ax1, '$x_2$', 'Interpreter', 'latex');
        if is3D
            zlabel(ax1, '$x_3$', 'Interpreter', 'latex');
            view(ax1, -37.5, 30);
        end

        %% Title
        title(ax1, sprintf('%s Decision Space ($\\mathrm{HV}:%.4f\\;\\rightarrow\\;%.4f$)', ...
            problemName, Hypervolumes(1), Hypervolumes(end)), ...
            'Interpreter', 'latex', ...
            'FontSize', 20, 'FontWeight', 'bold');

        %% Legend
        leg_handles_dec = [h_refPS, h_init_dec, h_final_dec];
        if isgraphics(h_traj_dec), leg_handles_dec(end+1) = h_traj_dec; end
        legend(ax1, leg_handles_dec, 'Location', loc, 'Interpreter', 'latex');

        %% Axes limits
        data_dec = [IPD(:,1:nDec); FPD(:,1:nDec); all_decs(:,1:nDec); RefPS(:,1:nDec)];
        setTightAxes(ax1, data_dec);

        %% Final font & export
        set(ax1, 'FontSize', 24, 'FontName', 'Times');
        EnlargeFont();

        imgDir = './Visualization/images';
        if ~exist(imgDir, 'dir'), mkdir(imgDir); end
        print(fullfile(imgDir, sprintf('%s_Decision.eps', problemName)), '-depsc');
    end

    %% ===================== (4) OBJECTIVE SPACE FIGURE =====================
    nObj = min(size(RefPF, 2), 3);
    is3DObj = nObj >= 3;

    if ishandle(2) && strcmp(get(2, 'Type'), 'figure')
        fig2 = figure(2);
    else
        fig2 = figure('Position', [250, 100, fig_width, fig_height], ...
                  'Color', 'w', ...
                  'Name', sprintf('%s - Objective Space', problemName));
    end

    ax2 = axes('Parent', fig2, 'Position', [0.10, 0.15, 0.85, 0.75]);
    cla(ax2, 'reset'); hold(ax2, 'on'); grid(ax2, 'on'); box(ax2, 'on'); axis(ax2, 'tight');

    %% Reference PF (scatter — numerically computed, not analytical)
    if is3DObj
        h_refPF = scatter3(ax2, RefPF(:,1), RefPF(:,2), RefPF(:,3), ...
            20, Colors.front, 'filled', ...
            'MarkerFaceAlpha', 0.3, ...
            'DisplayName', sprintf('Reference PF (%d pts)', size(RefPF,1)));
    else
        h_refPF = scatter(ax2, RefPF(:,1), RefPF(:,2), ...
            20, Colors.front, 'filled', ...
            'MarkerFaceAlpha', 0.3, ...
            'DisplayName', sprintf('Reference PF (%d pts)', size(RefPF,1)));
    end

    %% Trajectories in objective space
    h_traj_obj = gobjects(1,1);
    if ~isempty(all_objs)
        nPts = size(all_objs, 1);
        t = linspace(0, 1, nPts)';
        C_traj = (1 - t) .* Colors.initial + t .* Colors.final;

        if is3DObj
            h_traj_obj = scatter3(ax2, ...
                all_objs(:,1), all_objs(:,2), all_objs(:,3), ...
                MarkerSize.trajectory, C_traj, ...
                'Marker', '.', ...
                'MarkerFaceAlpha', Alpha.traj, ...
                'MarkerEdgeAlpha', Alpha.traj, ...
                'DisplayName', 'Trajectory (red $\to$ green)');
        else
            h_traj_obj = scatter(ax2, ...
                all_objs(:,1), all_objs(:,2), ...
                MarkerSize.trajectory, C_traj, ...
                'Marker', '.', ...
                'MarkerFaceAlpha', Alpha.traj, ...
                'MarkerEdgeAlpha', Alpha.traj, ...
                'DisplayName', 'Trajectory (red $\to$ green)');
        end
    end

    %% Initial population (objective)
    IPO = Initial_Pop.objs;
    if is3DObj
        h_init_obj = scatter3(ax2, ...
            IPO(:,1), IPO(:,2), IPO(:,3), ...
            'SizeData', MarkerSize.initial, ...
            'CData', Colors.initial, ...
            'Marker', 'o', ...
            'MarkerFaceColor', 'flat', ...
            'MarkerEdgeColor', 'none', ...
            'DisplayName', 'Initial (iter 0)');
    else
        h_init_obj = scatter(ax2, ...
            IPO(:,1), IPO(:,2), ...
            'SizeData', MarkerSize.initial, ...
            'CData', Colors.initial, ...
            'Marker', 'o', ...
            'MarkerFaceColor', 'flat', ...
            'MarkerEdgeColor', 'none', ...
            'DisplayName', 'Initial (iter 0)');
    end

    %% Final population (objective)
    FPO = Final_Pop.objs;
    if is3DObj
        h_final_obj = scatter3(ax2, ...
            FPO(:,1), FPO(:,2), FPO(:,3), ...
            'SizeData', MarkerSize.final, ...
            'CData', Colors.final, ...
            'Marker', '^', ...
            'MarkerFaceColor', 'flat', ...
            'MarkerEdgeColor', 'none', ...
            'DisplayName', sprintf('Final (iter %d)', numel(Populations)-1));
    else
        h_final_obj = scatter(ax2, ...
            FPO(:,1), FPO(:,2), ...
            'SizeData', MarkerSize.final, ...
            'CData', Colors.final, ...
            'Marker', '^', ...
            'MarkerFaceColor', 'flat', ...
            'MarkerEdgeColor', 'none', ...
            'DisplayName', sprintf('Final (iter %d)', numel(Populations)-1));
    end

    %% Z-ordering
    uistack(h_refPF, 'bottom');
    uistack(h_traj_obj, 'top');
    uistack(h_init_obj, 'top');
    uistack(h_final_obj, 'top');

    %% Labels
    xlabel(ax2, '$f_1$', 'Interpreter', 'latex');
    ylabel(ax2, '$f_2$', 'Interpreter', 'latex');
    if is3DObj
        zlabel(ax2, '$f_3$', 'Interpreter', 'latex');
        view(ax2, -37.5, 30);
    end

    %% Title
    title(ax2, sprintf('%s Objective Space ($\\mathrm{HV}:%.4f\\;\\rightarrow\\;%.4f$)', ...
        problemName, Hypervolumes(1), Hypervolumes(end)), ...
        'Interpreter', 'latex', ...
        'FontSize', 20, 'FontWeight', 'bold');

    %% Legend
    leg_handles_obj = [h_refPF, h_init_obj, h_final_obj];
    if isgraphics(h_traj_obj), leg_handles_obj(end+1) = h_traj_obj; end
    legend(ax2, leg_handles_obj, 'Location', 'east', 'Interpreter', 'latex');

    %% Axes limits
    data_obj = [IPO(:,1:nObj); FPO(:,1:nObj); all_objs(:,1:nObj); RefPF(:,1:nObj)];
    setTightAxes(ax2, data_obj);

    %% Final font & export
    set(ax2, 'FontSize', 24, 'FontName', 'Times');
    EnlargeFont();

    imgDir = './Visualization/images';
    if ~exist(imgDir, 'dir'), mkdir(imgDir); end
    print(fullfile(imgDir, sprintf('%s_Objective.eps', problemName)), '-depsc');

    %% ===================== (5) SUMMARY (Console) =====================
    fprintf('\n=== Optimization Summary ===\n');
    fprintf('Problem: %s\n', problemName);
    fprintf('Total Iterations: %d\n', numel(Populations)-1);
    fprintf('Initial HV: %.4f\n', Hypervolumes(1));
    fprintf('Final HV: %.4f\n', Hypervolumes(end));
    fprintf('HV Improvement: %.4f (%.2f%%)\n', ...
        Hypervolumes(end) - Hypervolumes(1), ...
        100 * (Hypervolumes(end) - Hypervolumes(1)) / max(Hypervolumes(1), eps));

end

%% ===================== (HELPERS) =====================
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
