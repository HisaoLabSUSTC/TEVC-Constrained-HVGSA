% Decision space for Green population (two solutions on the t-axis)
PreprocessProductionImage(0.25, 0.3, 8.8);

% Draw the t-axis line
plot([0 1], [0 0], 'k-', 'LineWidth', 3);
hold on;

% Green population: two solutions
t_pop = [0.22, 0.71];
plot(t_pop, zeros(size(t_pop)), 'gs', 'MarkerSize', 30, 'MarkerFaceColor', 'g', 'LineWidth', 1.5);

% Formatting: labels only, no title, no legend, no ticks
xlabel('$t$', 'Interpreter', 'latex');
set(gca, 'XTick', [], 'YTick', [], 'YColor', 'none');
xlim([-0.05 1.05]);
ylim([-0.5 0.5]);
hold off;

filename = 'ProduceImage/images/DecisionSpaceGreen.png';
exportgraphics(gcf, filename, 'Resolution', 300);
close(gcf);
