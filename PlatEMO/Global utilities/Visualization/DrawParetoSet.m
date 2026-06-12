function DrawParetoSet(problemNames, exportImages)
%DRAWPARETOSET Visualize reference Pareto sets for RWMOP problems.
%
%   DrawParetoSet(problemNames)
%   DrawParetoSet(problemNames, exportImages)
%
%   Loads the stored reference PS for each problem and creates a
%   publication-quality 2D or 3D scatter plot in the decision space.
%
%   Input:
%     problemNames - String, char, or cell array of problem names
%                    (e.g., 'RWMOP10' or {'RWMOP1','RWMOP8','RWMOP10'})
%     exportImages - (optional) Logical, export PNG to ./Visualization/images/
%                    (default: false)
%
%   Examples:
%     DrawParetoSet('RWMOP10')
%     DrawParetoSet({'RWMOP1','RWMOP10'}, true)

    if nargin < 2, exportImages = false; end

    % Normalize input to cell array
    if ischar(problemNames) || isstring(problemNames)
        problemNames = {char(problemNames)};
    end

    if exportImages
        imgDir = './Visualization/images';
        if ~exist(imgDir, 'dir'), mkdir(imgDir); end
    end

    for i = 1:numel(problemNames)
        probName = problemNames{i};
        fprintf('Drawing PS for %s... ', probName);

        try
            [~, ~, ~, PS] = loadReferencePF(probName);
        catch ME
            fprintf('SKIPPED (%s)\n', ME.message);
            continue;
        end

        D = size(PS, 2);

        if D < 2
            fprintf('SKIPPED (%d variable, need at least 2D)\n', D);
            continue;
        end

        if D > 3
            fprintf('SKIPPED (%d variables, only 2D/3D supported)\n', D);
            continue;
        end

        plotReferencePS(PS, probName, D);

        if exportImages
            filename = fullfile(imgDir, sprintf('PS-%s.png', probName));
            exportgraphics(gcf, filename, 'Resolution', 300);
            fprintf('exported to %s\n', filename);
        else
            fprintf('done\n');
        end
    end
end

%% ==================== Plotting ====================

function plotReferencePS(PS, probName, D)
    PreprocessProductionImage(0.2, 1, 8.8);
    ax = gca;
    cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');

    % Plot reference PS
    if D == 2
        plot(ax, PS(:,1), PS(:,2), '.k', 'MarkerSize', 8);
    elseif D == 3
        plot3(ax, PS(:,1), PS(:,2), PS(:,3), '.k', 'MarkerSize', 8);
    end

    % Labels
    xlabel(ax, '$x_1$', 'Interpreter', 'Latex');
    ylabel(ax, '$x_2$', 'Interpreter', 'Latex');

    % Legend
    hold(ax, 'on');
    h1 = plot(ax, NaN, NaN, '.k', 'MarkerSize', 8);
    legend(ax, h1, sprintf('Reference PS (%d pts)', size(PS,1)), ...
        'Location', 'best');

    if D == 3
        zlabel(ax, '$x_3$', 'Interpreter', 'Latex');
        view(ax, 135, 30);
        lighting(ax, 'gouraud');
        light('Position', [1 1 1], 'Style', 'infinite');
        light('Position', [-1 -1 -1], 'Style', 'infinite', 'Color', [0.3 0.3 0.3]);
    else
        view(ax, 2);
    end

    title(ax, sprintf('%s (D=%d)', probName, D), ...
        'FontName', 'Times New Roman');
end
