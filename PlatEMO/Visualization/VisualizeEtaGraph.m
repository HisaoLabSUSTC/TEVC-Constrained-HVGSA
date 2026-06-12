function VisualizeEtaGraph(tested_etas, tested_phis, X0, ref, Gradient, Problem, iter)

    titleStr = sprintf("Eta graph at iteration %d on problem %s", iter, class(Problem));
    hFig = figure('Name', titleStr, 'Position', [100, 100, 1300, 600]);
    etas = linspace(0, 1, 101);
    HV_along_Gradient = double.empty([0 size(etas,  2)]);
    N = numel(X0);
    x0flat = Flatten(X0.decs);
    for i = 1:numel(etas)
        eta = etas(i);
        x1flat = x0flat + Gradient .* eta;
        x1 = Unflatten(x1flat, N);
        X1 = Problem.Evaluation(x1);

        HV_along_Gradient(i) = ComputeHV(X1, ref, "Feasible");
    end
    hold on
    hGradient = plot(etas, HV_along_Gradient, 'LineWidth', 2);
    xlim([0 1]);
    hx = xlabel("Step size");
    hy = ylabel("Hypervolume");

    for i=1:numel(tested_etas)
        temp_text = sprintf("GSA-\\eta_{%d}", i-1);
        hs = scatter(tested_etas(i), tested_phis(i));
        text(tested_etas(i), tested_phis(i), temp_text, ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'top', 'FontSize', 20);
    end

    lgd = legend([hGradient], {"eta-plot yielded by GSA"}, 'Location', 'Best');
    htitle = title(titleStr);
    EnlargeFont();
end
