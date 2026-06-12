function applyAxisExponentLabels(ax, xLabelBase, yLabelBase, zLabelBase)
%APPLYAXISEXPONENTLABELS Bake non-zero axis exponents into axis labels.
%
%   applyAxisExponentLabels(ax, xLabelBase, yLabelBase)
%   applyAxisExponentLabels(ax, xLabelBase, yLabelBase, zLabelBase)
%
%   For each axis whose Exponent is non-zero, appends " $(10^{N})$" to the
%   supplied base label (LaTeX interpreter), sets Exponent to 0, and rescales
%   the tick labels so the displayed numbers remain correct. Axes whose
%   Exponent is already 0 just get the plain base label.
%
%   This avoids the ugly "\times 10^{N}" overlay MATLAB draws at the corner
%   of axes with large-magnitude ticks.
%
%   Inputs:
%     ax         - target axes handle
%     xLabelBase - LaTeX string for x-axis (without exponent suffix)
%     yLabelBase - LaTeX string for y-axis (without exponent suffix)
%     zLabelBase - (optional) LaTeX string for z-axis

    if nargin < 4
        zLabelBase = '';
    end

    is3D = ~isempty(zLabelBase);

    xexp = double(ax.XAxis.Exponent);
    yexp = double(ax.YAxis.Exponent);
    if is3D
        zexp = double(ax.ZAxis.Exponent);
    end

    if xexp ~= 0
        xlabel(ax, sprintf('%s $(10^{%d})$', xLabelBase, xexp), ...
            'Interpreter', 'latex');
    else
        xlabel(ax, xLabelBase, 'Interpreter', 'latex');
    end

    if yexp ~= 0
        ylabel(ax, sprintf('%s $(10^{%d})$', yLabelBase, yexp), ...
            'Interpreter', 'latex');
    else
        ylabel(ax, yLabelBase, 'Interpreter', 'latex');
    end

    if is3D
        if zexp ~= 0
            zlabel(ax, sprintf('%s $(10^{%d})$', zLabelBase, zexp), ...
                'Interpreter', 'latex');
        else
            zlabel(ax, zLabelBase, 'Interpreter', 'latex');
        end
    end

    if xexp ~= 0
        ax.XAxis.Exponent = 0;
        xticklabels(ax, string(xticks(ax) / 10^xexp));
    end
    if yexp ~= 0
        ax.YAxis.Exponent = 0;
        yticklabels(ax, string(yticks(ax) / 10^yexp));
    end
    if is3D && zexp ~= 0
        ax.ZAxis.Exponent = 0;
        zticklabels(ax, string(zticks(ax) / 10^zexp));
    end
end
