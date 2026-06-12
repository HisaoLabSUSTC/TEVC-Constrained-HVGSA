function VisualizeEtaCVGraphNorm(tested_etas, tested_phis, Xs, X0, ref, NormStruct, Gradient, Problem, iter)
    titleStr = sprintf("Eta graph at iteration %d on problem %s", iter, class(Problem));
    hFig = figure('Name', titleStr, 'Position', [100, 100, 1300, 600]);
    etas = linspace(0, 1, 101);

    HV_along_Gradient = double.empty([0 size(etas,  2)]);
    minCV_along_Gradient = double.empty([0 size(etas,  2)]);
    avgCV_along_Gradient = double.empty([0 size(etas,  2)]);
    maxCV_along_Gradient = double.empty([0 size(etas,  2)]);

    N = numel(X0);
    x0flat = Flatten(X0.decs);
    for i = 1:numel(etas)
        eta = etas(i);
        x1flat = x0flat + Gradient .* eta;
        x1 = Unflatten(x1flat, N);
        X1 = Problem.Evaluation(x1);

        [Norm_X1_objs, Norm_X1_cons, ~] = ...
                    NormReference(X1.objs, X1.cons, NormStruct);
        Norm_X1 = SOLUTION(X1.decs, Norm_X1_objs, Norm_X1_cons);
        [mCV_X1, aCV_X1, MCV_X1] = TotalCV(Norm_X1.cons);

        HV_along_Gradient(i) = ComputeHV(Norm_X1, ref, "Feasible");
        minCV_along_Gradient(i) = mCV_X1;
        avgCV_along_Gradient(i) = aCV_X1;
        maxCV_along_Gradient(i) = MCV_X1;
    end

    subplot(1, 2, 1)
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
    % htitle = title(titleStr);

    subplot(1, 2, 2)
    hold on
    hCV_min = plot(etas, minCV_along_Gradient, 'LineWidth', 2, 'Color', 'cyan');
    hCV_avg = plot(etas, avgCV_along_Gradient, 'LineWidth', 2, 'Color', 'red');
    hCV_max = plot(etas, maxCV_along_Gradient, 'LineWidth', 2, 'Color', 'blue');
    xlim([0 1]);
    hx = xlabel("Step size");
    hy = ylabel("Total CV");

    for i=1:numel(tested_etas)
        temp_text = sprintf("GSA-\\eta_{%d}", i-1);

        start = (i-1)*N+1;
        finish = start+N-1;
        Xi = Xs(start:finish);
        [Norm_Xi_objs, Norm_Xi_cons, ~] = ...
                    NormReference(Xi.objs, Xi.cons, NormStruct);
        Norm_Xi = SOLUTION(Xi.decs, Norm_Xi_objs, Norm_Xi_cons);
        [mCV_Xi, aCV_Xi, MCV_Xi] = TotalCV(Norm_Xi.cons);

        hm = scatter(tested_etas(i), mCV_Xi);
        ha = scatter(tested_etas(i), aCV_Xi);
        hM = scatter(tested_etas(i), MCV_Xi);

        text(tested_etas(i), aCV_Xi, temp_text, ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'top', 'FontSize', 20);
    end

    lgd = legend([hCV_min, hCV_avg, hCV_max], {"min CV", "avg CV", "max CV"}, 'Location', 'Best');
    
    htitle = sgtitle(titleStr);

    EnlargeFont();
end
