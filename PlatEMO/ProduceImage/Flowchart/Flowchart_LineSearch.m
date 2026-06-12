% Flowchart_LineSearch.m
% Illustrates Armijo backtracking line search along the GSA direction
%
% phi(eta) = Lambda(X_0 + eta * nu_S*) is the hypervolume evaluated
% along the search direction. The Armijo condition accepts eta when
% phi(eta) >= phi(0) + c_alpha * eta * phi'(0).
%
% Three trial steps are shown:
%   eta_0 = 1.5   (rejected — curve below Armijo line)
%   eta_1 = 0.75  (rejected — curve below Armijo line)
%   eta*  = 0.375 (accepted — curve above Armijo line)

%% Parameters
scale = 8.8;
phi_0 = 1.5;          % phi(0): HV at current iterate
slope = 5.0;           % phi'(0): directional derivative (> 0, ascent)
c_a   = 0.25;          % Armijo parameter

% Stylized line search function: initial ascent then decay
phi    = @(eta) phi_0 + slope * eta .* exp(-2.5 * eta);
armijo = @(eta) phi_0 + c_a * slope * eta;
eta    = linspace(0, 2, 1000);

%% Create figure
PreprocessProductionImage(0.4, 0.8, scale);

% Shaded region where Armijo condition is satisfied (phi >= armijo)
eta_cross = log(1 / c_a) / 2.5;           % crossing point: phi = armijo
ef        = linspace(0, eta_cross, 200);
fill([ef fliplr(ef)], [phi(ef) armijo(fliplr(ef))], ...
     [0.85 0.95 0.85], 'EdgeColor', 'none', 'FaceAlpha', 0.8);
hold on;

% phi(eta) curve (HV along search direction)
plot(eta, phi(eta), 'k-', 'LineWidth', 9);

% Armijo sufficient decrease line
plot(eta, armijo(eta), '--', 'Color', [0.8 0 0], 'LineWidth', 6);

% phi(0) horizontal reference
plot([0 2], [phi_0 phi_0], 'k:', 'LineWidth', 3);

% Starting point marker
plot(0, phi_0, 'ko', 'MarkerSize', 10, 'MarkerFaceColor', 'k', 'LineWidth', 4.5);

%% Backtracking trial points: eta_0 -> eta_0/2 -> eta_0/4
et = [1.5, 0.75, 0.375];

% Rejected trials: vertical dashed lines + red X markers
for i = 1:2
    plot([et(i) et(i)], [phi_0 phi(et(i))], ...
        ':', 'Color', [0.6 0.15 0.15], 'LineWidth', 3);
    plot(et(i), phi(et(i)), 'x', 'Color', [0.8 0 0], ...
        'MarkerSize', 20, 'LineWidth', 4.5);
end

% Accepted trial: vertical dashed line + green filled circle
plot([et(3) et(3)], [phi_0 phi(et(3))], ...
    ':', 'Color', [0 0.5 0], 'LineWidth', 3);
plot(et(3), phi(et(3)), 'o', 'Color', [0 0.6 0], ...
    'MarkerSize', 16, 'MarkerFaceColor', [0 0.8 0], 'LineWidth', 4.5);

% Backtracking arrows (blue, pointing left — reducing step size)
ya = phi_0 - 0.08;
% for i = 1:2
%     dx = (et(i+1) - et(i)) * 0.85;
%     quiver(et(i), ya, dx, 0, 0, ...
%         'Color', [0.2 0.2 0.8], 'LineWidth', 2, 'MaxHeadSize', 0.6);
% end

%% Text annotations (font sizes proportional to scale for paper export)
fs  = 5 * scale;    % main labels
fss = 4 * scale;    % smaller annotations

% phi(eta) curve label (above curve on the right)
text(0.7, phi(0.75) + 0.18, '$\phi(\eta_1)$', ...
    'Interpreter', 'latex', 'FontSize', fs);
text(1.4, phi(1.5) + 0.2, '$\phi(\eta_0)$', ...
    'Interpreter', 'latex', 'FontSize', fs);

text(0.72, phi_0 - 0.15, '$\eta_1$', ...
    'Interpreter', 'latex', 'FontSize', fs);
text(1.47, phi_0 - 0.15, '$\eta_0$', ...
    'Interpreter', 'latex', 'FontSize', fs);


% Armijo line label (above the red dashed line)
text(1.25, armijo(1.0) + 0.2, '$\phi(0) + c_\alpha \eta \phi''(0)$', ...
    'Interpreter', 'latex', 'FontSize', fss, 'Color', [0.8 0 0]);

% phi(0) = Lambda(X_0) label
text(0 - 0.31, phi_0, '$\Lambda(\mathbf{X}_0)$', ...
    'Interpreter', 'latex', 'FontSize', fss);

% Trial step labels (below the backtracking arrows)
% text(et(1), ya - 0.1, '$\eta_0$', ...
%     'Interpreter', 'latex', 'FontSize', fss, 'HorizontalAlignment', 'center');
% text(et(2), ya - 0.1, '$\eta_1$', ...
%     'Interpreter', 'latex', 'FontSize', fss, 'HorizontalAlignment', 'center');

% Accepted step label (above the green marker)
text(et(3)-0.1, phi(et(3)) + 0.2, '$\phi(\eta^*)$', ...
    'Interpreter', 'latex', 'FontSize', fs, 'Color', [0 0.6 0]);
text(et(3)-0.03, phi_0 - 0.15, '$\eta^*$', ...
    'Interpreter', 'latex', 'FontSize', fs, 'Color', [0 0.6 0]);

%% Formatting: labels only, no title, no legend, no ticks
xlabel('$\eta$', 'Interpreter', 'latex');
ylabel('$\phi(\eta)$', 'Interpreter', 'latex', 'Rotation', 0);
set(gca, 'XTick', [], 'YTick', []);
xlim([0 2]);
ylim([1.1 4.0]);
grid on;
hold off;

filename = 'ProduceImage/images/LineSearch.png';
exportgraphics(gcf, filename, 'Resolution', 300);
close(gcf);
