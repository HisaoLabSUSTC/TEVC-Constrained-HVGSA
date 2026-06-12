function VisualizeCBOP(viz_data, Problem)
%% ===============================================================
%  CBOP Visualization (Publication-Grade; Decision & Objective Spaces)
%  ---------------------------------------------------------------
%  - LaTeX labels/titles, docking-safe axes reset, explicit handles
%  - Legend order and naming standardized
%  - EPS export for production use (TEVC/IEEE-friendly)
%  - Matches the visual language used in your Examples 1–4
%  ---------------------------------------------------------------

    fig_width = 1200;
    fig_height = 1200;

    %% ===================== (1) COLOR & STYLE SETTINGS =====================
    %% Colors (consistent palette)
    Colors.front         = [0.00, 0.00, 0.00];   % Black: true front
    Colors.constrained   = [1.00, 0.55, 0.31];   % Orange: constrained PS/PF
    Colors.unconstrained = [0.68, 0.85, 0.90];   % Light blue: unconstrained PS/PF
    Colors.initial       = [0.80, 0.20, 0.20];   % Red: initial population
    Colors.final         = [0.20, 0.60, 0.20];   % Green: final population
    Colors.trajectory    = [0.55, 0.20, 0.55];   % Purple: trajectories
    Colors.reference     = [0.10, 0.30, 0.70];   % Blue: reference point

    %% Alpha (transparency)
    Alpha.traj   = 0.35;  % trajectories (mid-iterations)
    Alpha.init   = 0.95;
    Alpha.final  = 0.95;

    %% Marker sizes
    MarkerSize.initial    = 300;
    MarkerSize.final      = 300;
    MarkerSize.trajectory = 100;   % dot cloud size for clarity
    MarkerSize.reference  = 300;

    %% Line widths
    LW.front  = 8.0;
    LW.pspf   = 8.0;      % lines for PS/PF
    LW.upspf = 5.0;
    LW.edge   = 1.2;      % scatter edge

    %% legend location
    loc = "southeast";

    %% ===================== (2) DATA EXTRACTION =====================
    Populations  = viz_data.Populations;
    Hypervolumes = cell2mat(viz_data.Hypervolume);
    Initial_Pop  = Populations{1};
    Final_Pop    = Populations{end};
    ref = viz_data.Ref;

    isConstr = isConstrained(Problem);

    % Get PS and PF (100-point resolution) and reference (if available)
    PF  = GetOptimum(Problem, 100);
    PS  = GetPS(Problem, 100);

    % Partition constrained vs. unconstrained sets for labeling
    if isConstr
        %% Trick to get UPS for constrained problems
        Unconstr_Handle = @CBOP0;
        Unconstr_Problem = Unconstr_Handle();
        UPS = GetPS(Unconstr_Problem, 100);
        UPF = GetOptimum(Unconstr_Problem, 100);

        CPS = PS;  CPF = PF;
    else
        UPS = PS;  UPF = PF;
        CPS = [];  CPF = [];
    end

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
    if ishandle(1) && strcmp(get(1, 'Type'), 'figure')
        disp('Figure 1 exists.');
        fig1 = figure(1);
    else
        disp('Figure 1 does not exist.');
        fig1 = figure('Position', [100, 100, fig_width, fig_height], ...
                  'Color', 'w', ...
                  'Name', 'CBOP - Decision Space');
    end

    ax1 = axes('Parent', fig1, 'Position', [0.10, 0.15, 0.85, 0.75]);

    %% Axes reset & scaffolding
    cla(ax1, 'reset'); hold(ax1, 'on'); grid(ax1, 'on'); box(ax1, 'on'); axis(ax1, 'tight');

    %% (Contents) True Pareto set (UPS/CPS) in decision space
    h_upS = gobjects(1,1); h_cpS = gobjects(1,1);
    if ~isConstr
        h_upS = plot(ax1, UPS(:,1), UPS(:,2), '-', ...
            'Color', 'k', ...
            'LineWidth', LW.pspf, ...
            'DisplayName', 'True PS');
    else
        h_upS = plot(ax1, UPS(:,1), UPS(:,2), ':', ...
            'Color', [0.6510    0.6510    0.6510], ...
            'LineWidth', LW.upspf, ...
            'DisplayName', 'Unconstrained PS');
        h_cpS = plot(ax1, CPS(:,1), CPS(:,2), '-', ...
            'Color', 'k', ...
            'LineWidth', LW.pspf, ...
            'DisplayName', 'True PS');
        uistack(h_upS, 'top');
    end

    %% (Contents) Trajectories in decision space (Gradient: red → green on scatter)
    h_traj_dec = gobjects(1,1);
    if ~isempty(all_decs)
        nPts = size(all_decs, 1);
        t = linspace(0, 1, nPts)';  % normalized progression
    
        % Create per-point color: red → green transition
        C_traj = (1 - t) .* Colors.initial + t .* Colors.final;
    
        h_traj_dec = scatter(ax1, ...
            all_decs(:,1), all_decs(:,2), ...
            MarkerSize.trajectory, ...
            C_traj, ...                     % gradient colors
            'Marker', '.', ...
            'MarkerFaceAlpha', Alpha.traj, ...
            'MarkerEdgeAlpha', Alpha.traj, ...
            'DisplayName', 'Trajectory (red $\to$ green)');
    end



    %% (Contents) Initial population (decision)
    IPD = Initial_Pop.decs;
    h_init_dec = scatter(ax1, ...
        IPD(:,1), IPD(:,2), ...
        'SizeData', MarkerSize.initial, ...
        'CData', Colors.initial, ...
        'Marker', 'o', ...
        'MarkerFaceColor', 'flat', ...
        'MarkerEdgeColor', 'none', ...
        'DisplayName', 'Initial (iter 0)');

    %% (Contents) Final population (decision)
    FPD = Final_Pop.decs;
    h_final_dec = scatter(ax1, ...
        FPD(:,1), FPD(:,2), ...
        'SizeData', MarkerSize.final, ...
        'CData', Colors.final, ...
        'Marker', '^', ...
        'MarkerFaceColor', 'flat', ...
        'MarkerEdgeColor', 'none', ...
        'DisplayName', sprintf('Final (iter %d)', numel(Populations)-1));

    uistack(h_traj_dec, 'top');
    %% Labels (LaTeX)
    xlabel(ax1, '$x_1$', 'Interpreter', 'latex');
    ylabel(ax1, '$x_2$', 'Interpreter', 'latex');

    %% Title (LaTeX; Option B)
    title(ax1, sprintf('Decision Space ($\\mathrm{HV}:%.4f\\;\\rightarrow\\;%.4f$)', ...
        Hypervolumes(1), Hypervolumes(end)), ...
        'Interpreter', 'latex', ...
        'FontSize', 20, 'FontWeight', 'bold');

    if isgraphics(h_cpS)
        uistack(h_cpS, 'top')
    end
    uistack(h_upS, 'top')
    uistack(h_traj_dec, 'top')
    uistack(h_init_dec, 'top')
    uistack(h_final_dec, 'top')

    %% Legend (ordered): PS → Traj → Initial → Final
    leg_handles_dec = [];
    if isgraphics(h_upS),     leg_handles_dec(end+1) = h_upS;     end %#ok<AGROW>
    if isgraphics(h_cpS),     leg_handles_dec(end+1) = h_cpS;     end %#ok<AGROW>
    leg_handles_dec(end+1) = h_init_dec; %#ok<AGROW>
    leg_handles_dec(end+1) = h_final_dec; %#ok<AGROW>
    if isgraphics(h_traj_dec),leg_handles_dec(end+1) = h_traj_dec;end %#ok<AGROW>
    legend(ax1, leg_handles_dec, 'Location', loc, 'Interpreter', 'latex');

    %% Axes limits (tight with padding)
    data_dec = [IPD; FPD; all_decs];
    if ~isempty(UPS), data_dec = [data_dec; UPS]; end %#ok<AGROW>
    if ~isempty(CPS), data_dec = [data_dec; CPS]; end %#ok<AGROW>
    setTightAxes(ax1, data_dec);

    %% Final font & export (Decision)
    set(ax1, 'FontSize', 24, 'FontName', 'Times');
    EnlargeFont();
    print('./Visualization/images/CBOP_Decision.eps','-depsc');

    %% ===================== (4) OBJECTIVE SPACE FIGURE =====================
    if ishandle(2) && strcmp(get(2, 'Type'), 'figure')
        disp('Figure 2 exists.');
        fig2 = figure(2);
    else
        disp('Figure 2 does not exist.');
        fig2 = figure('Position', [250, 100, fig_width, fig_height], ...
                  'Color', 'w', ...
                  'Name', 'CBOP - Objective Space');
    end

    ax2 = axes('Parent', fig2, 'Position', [0.10, 0.15, 0.85, 0.75]);

    %% Axes reset & scaffolding
    cla(ax2, 'reset'); hold(ax2, 'on'); grid(ax2, 'on'); box(ax2, 'on'); axis(ax2, 'tight');

    %% (Contents) True Pareto front (UPF/CPF) in objective space
    h_upF = gobjects(1,1); h_cpF = gobjects(1,1);
    if ~isConstr
        h_upF = plot(ax2, UPF(:,1), UPF(:,2), '-', ...
            'Color', 'k', ...
            'LineWidth', LW.pspf, ...
            'DisplayName', 'True PF');
    else
        h_upF = plot(ax2, UPF(:,1), UPF(:,2), ':', ...
            'Color', [0.6510    0.6510    0.6510], ...
            'LineWidth', LW.upspf, ...
            'DisplayName', 'Unconstrained PF');
        h_cpF = plot(ax2, CPF(:,1), CPF(:,2), '-', ...
            'Color', 'k', ...
            'LineWidth', LW.pspf, ...
            'DisplayName', 'True PF');
        uistack(h_upF, 'top');
    end

    %% (Contents) Trajectories in objective space (Gradient: red → green on scatter)
    h_traj_obj = gobjects(1,1);
    if ~isempty(all_objs)
        nPts = size(all_objs, 1);
        t = linspace(0, 1, nPts)';  % normalized progression
    
        % Create per-point color: red → green transition
        C_traj = (1 - t) .* Colors.initial + t .* Colors.final;
    
        h_traj_obj = scatter(ax2, ...
            all_objs(:,1), all_objs(:,2), ...
            MarkerSize.trajectory, ...
            C_traj, ...                     % gradient colors
            'Marker', '.', ...
            'MarkerFaceAlpha', Alpha.traj, ...
            'MarkerEdgeAlpha', Alpha.traj, ...
            'DisplayName', 'Trajectory (red $\to$ green)');
    end

    %% (Contents) Initial population (objective)
    IPO = Initial_Pop.objs;
    h_init_obj = scatter(ax2, ...
        IPO(:,1), IPO(:,2), ...
        'SizeData', MarkerSize.initial, ...
        'CData', Colors.initial, ...
        'Marker', 'o', ...
        'MarkerFaceColor', 'flat', ...
        'MarkerEdgeColor', 'none', ...
        'DisplayName', 'Initial (iter 0)');

    %% (Contents) Final population (objective)
    FPO = Final_Pop.objs;
    h_final_obj = scatter(ax2, ...
        FPO(:,1), FPO(:,2), ...
        'SizeData', MarkerSize.final, ...
        'CData', Colors.final, ...
        'Marker', '^', ...
        'MarkerFaceColor', 'flat', ...
        'MarkerEdgeColor', 'none', ...
        'DisplayName', sprintf('Final (iter %d)', numel(Populations)-1));

    %% (Contents) Reference point (if provided)
    h_ref = gobjects(1,1);
    if ~isempty(ref) && numel(ref) == 2
        h_ref = scatter(ax2, ...
            ref(1), ref(2), ...
            'SizeData', MarkerSize.reference, ...
            'CData', Colors.reference, ...
            'Marker', 's', ...
            'MarkerFaceColor', 'flat', ...
            'MarkerEdgeColor', 'k', ...
            'LineWidth', LW.edge, ...
            'DisplayName', 'Reference Point');
    end


    if isgraphics(h_cpF)
        uistack(h_cpF, 'top')
    end
    uistack(h_upF, 'top')
    uistack(h_traj_obj, 'top')
    uistack(h_init_obj, 'top')
    uistack(h_final_obj, 'top')


    %% Labels (LaTeX)
    xlabel(ax2, '$f_1$', 'Interpreter', 'latex');
    ylabel(ax2, '$f_2$', 'Interpreter', 'latex');

    %% Title (LaTeX; Option B)
    title(ax2, sprintf('Objective Space ($\\mathrm{HV}:%.4f\\;\\rightarrow\\;%.4f$)', ...
        Hypervolumes(1), Hypervolumes(end)), ...
        'Interpreter', 'latex', ...
        'FontSize', 20, 'FontWeight', 'bold');

    %% Legend (ordered): PF → Traj → Initial → Final → Reference
    leg_handles_obj = [];
    if isgraphics(h_upF),      leg_handles_obj(end+1) = h_upF;      end %#ok<AGROW>
    if isgraphics(h_cpF),      leg_handles_obj(end+1) = h_cpF;      end %#ok<AGROW>
    leg_handles_obj(end+1) = h_init_obj; %#ok<AGROW>
    leg_handles_obj(end+1) = h_final_obj; %#ok<AGROW>
    if isgraphics(h_traj_obj), leg_handles_obj(end+1) = h_traj_obj; end %#ok<AGROW>
    if isgraphics(h_ref),      leg_handles_obj(end+1) = h_ref;      end %#ok<AGROW>
    legend(ax2, leg_handles_obj, 'Location', 'east', 'Interpreter', 'latex');

    %% Axes limits (tight with padding)
    data_obj = [IPO; FPO; all_objs];
    if ~isempty(UPF), data_obj = [data_obj; UPF]; end %#ok<AGROW>
    if ~isempty(CPF), data_obj = [data_obj; CPF]; end %#ok<AGROW>
    if ~isempty(ref), data_obj = [data_obj; ref]; end %#ok<AGROW>
    setTightAxes(ax2, data_obj);

    %% Final font & export (Objective)
    set(ax2, 'FontSize', 24, 'FontName', 'Times');
    EnlargeFont();
    print('./Visualization/images/CBOP_Objective.eps','-depsc');

    %% ===================== (5) SUMMARY (Console) =====================
    problem_type = ternary(isConstr, 'Constrained', 'Unconstrained');
    fprintf('\n=== Optimization Summary ===\n');
    fprintf('Problem: %s (%s)\n', class(Problem), problem_type);
    fprintf('Total Iterations: %d\n', numel(Populations)-1);
    fprintf('Initial HV: %.4f\n', Hypervolumes(1));
    fprintf('Final HV: %.4f\n', Hypervolumes(end));
    fprintf('HV Improvement: %.4f (%.2f%%)\n', ...
        Hypervolumes(end) - Hypervolumes(1), ...
        100 * (Hypervolumes(end) - Hypervolumes(1)) / max(Hypervolumes(1), eps));

end

%% ===================== (HELPERS) =====================
function result = ternary(condition, true_val, false_val)
    if condition, result = true_val; else, result = false_val; end
end

function setTightAxes(ax, data)
% Tight axis limits with small padding; no-op if data empty/degenerate.
    if isempty(data) || size(data,2) ~= 2
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
end


