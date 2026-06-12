function DrawParetoFront(problemNames, exportImages)
%DRAWPARETOFRONT Visualize reference Pareto fronts for RWMOP problems.
%
%   DrawParetoFront(problemNames)
%   DrawParetoFront(problemNames, exportImages)
%
%   Loads the stored reference PF for each problem and creates a
%   publication-quality 2D or 3D scatter plot with ideal/nadir overlay.
%
%   Input:
%     problemNames - String, char, or cell array of problem names
%                    (e.g., 'RWMOP1' or {'RWMOP1','RWMOP8','RWMOP24'})
%     exportImages - (optional) Logical, export PNG to ./Visualization/images/
%                    (default: false)
%
%   Examples:
%     DrawParetoFront('RWMOP1')
%     DrawParetoFront({'RWMOP1','RWMOP8','RWMOP24'}, true)

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
        fprintf('Drawing PF for %s... ', probName);

        try
            [PF, ideal, nadir] = loadReferencePF(probName);
        catch ME
            fprintf('SKIPPED (%s)\n', ME.message);
            continue;
        end

        M = size(PF, 2);

        if M > 3
            fprintf('SKIPPED (%d objectives, only 2D/3D supported)\n', M);
            continue;
        end

        plotReferencePF(PF, ideal, nadir, probName, M);

        if exportImages
            filename = fullfile(imgDir, sprintf('PF-%s.png', probName));
            exportgraphics(gcf, filename, 'Resolution', 300);
            fprintf('exported to %s\n', filename);
        else
            fprintf('done\n');
        end
    end
end

%% ==================== Plotting ====================

function plotReferencePF(PF, ideal, nadir, probName, M)
    PreprocessProductionImage(0.2, 1, 8.8);
    ax = gca;
    cla(ax); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');

    % Plot reference PF
    if M == 2
        plot(ax, PF(:,1), PF(:,2), '.k', 'MarkerSize', 8);
        plot(ax, ideal(1), ideal(2), 'pb', 'MarkerSize', 12, 'MarkerFaceColor', 'b');
        plot(ax, nadir(1), nadir(2), 'pr', 'MarkerSize', 12, 'MarkerFaceColor', 'r');
    elseif M == 3
        plot3(ax, PF(:,1), PF(:,2), PF(:,3), '.k', 'MarkerSize', 8);
        plot3(ax, ideal(1), ideal(2), ideal(3), 'pb', 'MarkerSize', 12, 'MarkerFaceColor', 'b');
        plot3(ax, nadir(1), nadir(2), nadir(3), 'pr', 'MarkerSize', 12, 'MarkerFaceColor', 'r');
    end

    % Plot extreme points
    extreme_points = getExtremePoints(PF);
    if M == 2
        plot(ax, extreme_points(:,1), extreme_points(:,2), ...
            'dg', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
    elseif M == 3
        plot3(ax, extreme_points(:,1), extreme_points(:,2), extreme_points(:,3), ...
            'dg', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
    end

    % Labels
    xlabel(ax, '$f_1$', 'Interpreter', 'Latex');
    ylabel(ax, '$f_2$', 'Interpreter', 'Latex');

    % Legend
    hold(ax, 'on');
    h1 = plot(ax, NaN, NaN, '.k', 'MarkerSize', 8);
    h2 = plot(ax, NaN, NaN, 'pb', 'MarkerSize', 12, 'MarkerFaceColor', 'b');
    h3 = plot(ax, NaN, NaN, 'pr', 'MarkerSize', 12, 'MarkerFaceColor', 'r');
    h4 = plot(ax, NaN, NaN, 'dg', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
    legend(ax, [h1, h2, h3, h4], ...
        sprintf('Reference PF (%d pts)', size(PF,1)), ...
        'Ideal point', 'Nadir point', 'Extreme points', ...
        'Location', 'best');

    if M == 3
        zlabel(ax, '$f_3$', 'Interpreter', 'Latex');
        view(ax, 135, 30);
        lighting(ax, 'gouraud');
        light('Position', [1 1 1], 'Style', 'infinite');
        light('Position', [-1 -1 -1], 'Style', 'infinite', 'Color', [0.3 0.3 0.3]);
    else
        view(ax, 2);
    end

    title(ax, sprintf('%s (M=%d)', probName, M), ...
        'FontName', 'Times New Roman');
end

%% ==================== Helpers ====================

function extreme_points = getExtremePoints(F)
    ideal_point = min(F, [], 1);
    [N, M] = size(F);
    weights = zeros(M) + eye(M) + 1e-6;

    FFF = F - ideal_point;
    I = zeros(1, M);
    for i = 1:M
        [~, I(i)] = min(max(FFF ./ repmat(weights(i,:), N, 1), [], 2));
    end

    extreme_points = F(I, :);
end
