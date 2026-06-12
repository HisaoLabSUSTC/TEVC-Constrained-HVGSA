% Constrained Hypervolume landscape with C-HVGSA search direction (Newton step)
% Grid-sample pairs (t1, t2) and compute constrained HV for each 2-solution population
% The C-HVGSA direction incorporates constraint violations via the Newton correction

n = 1000;
t1_grid = linspace(0, 1, n);
t2_grid = linspace(0, 1, n);
[T1, T2] = meshgrid(t1_grid, t2_grid);

% Reference point
ref = [2, 2];

% Objective values for solution 1 (parameterized by t1)
F1_1 = T1 + 0.25 + 0.5 * cos(4*pi*T1);
F2_1 = 1.25 - T1 + 0.5 * cos(4*pi*T1);

% Objective values for solution 2 (parameterized by t2)
F1_2 = T2 + 0.25 + 0.5 * cos(4*pi*T2);
F2_2 = 1.25 - T2 + 0.5 * cos(4*pi*T2);

% Feasibility: a solution is feasible when f1 + f2 >= 0.7
% Constraint: c(t) = 0.7 - f1(t) - f2(t), positive means violated
feas1 = (F1_1 + F2_1) >= 0.7;
feas2 = (F1_2 + F2_2) >= 0.7;

% Individual rectangle areas and overlap
area1 = max(0, ref(1)-F1_1) .* max(0, ref(2)-F2_1);
area2 = max(0, ref(1)-F1_2) .* max(0, ref(2)-F2_2);
overlap = max(0, ref(1)-max(F1_1,F1_2)) .* max(0, ref(2)-max(F2_1,F2_2));

% Constrained HV: infeasible solutions contribute nothing
HV = feas1 .* feas2 .* (area1 + area2 - overlap) + ...
     feas1 .* ~feas2 .* area1 + ...
     ~feas1 .* feas2 .* area2;

% Create figure
PreprocessProductionImage(0.25, 1, 8.8);

% Heatmap
imagesc(t1_grid, t2_grid, HV);
axis xy;
hold on;

% Infeasible region overlay based on total constraint violation
cv1 = max(0, 0.7 - (F1_1 + F2_1));
cv2 = max(0, 0.7 - (F1_2 + F2_2));
total_cv = cv1 + cv2;
norm_cv = total_cv / max(total_cv(:));
black_img = zeros(n, n, 3);
h_infeas = imagesc(t1_grid, t2_grid, black_img);
set(h_infeas, 'AlphaData', norm_cv);

% Symmetry line (y = x)
plot([0 1], [0 1], 'k--', 'LineWidth', 2);

%% C-HVGSA computation with Newton step
% Population positions in decision space
x0 = [0.33, 0.68]; % Red (iterate)
x1 = [0.22, 0.71]; % Green (neighbor)
x2 = [0.37, 0.62]; % Blue (neighbor)

% Objective function helpers
f1_of = @(t) t + 0.25 + 0.5*cos(4*pi*t);
f2_of = @(t) 1.25 - t + 0.5*cos(4*pi*t);

% Constraint function: c(t) = 0.7 - f1(t) - f2(t) (positive = violated)
c_of = @(t) 0.7 - f1_of(t) - f2_of(t);

% Constrained HV for a 2-solution population:
% infeasible solutions contribute nothing to the hypervolume
chv_of = @(t) ...
    (c_of(t(1))<=0) * (c_of(t(2))<=0) * (...
        max(0,ref(1)-f1_of(t(1)))*max(0,ref(2)-f2_of(t(1))) + ...
        max(0,ref(1)-f1_of(t(2)))*max(0,ref(2)-f2_of(t(2))) - ...
        max(0,ref(1)-max(f1_of(t(1)),f1_of(t(2))))*max(0,ref(2)-max(f2_of(t(1)),f2_of(t(2))))) + ...
    (c_of(t(1))<=0) * (c_of(t(2))>0) * (...
        max(0,ref(1)-f1_of(t(1)))*max(0,ref(2)-f2_of(t(1)))) + ...
    (c_of(t(1))>0) * (c_of(t(2))<=0) * (...
        max(0,ref(1)-f1_of(t(2)))*max(0,ref(2)-f2_of(t(2))));

chv_x0 = chv_of(x0);
chv_x1 = chv_of(x1);
chv_x2 = chv_of(x2);

% Constraint flat vectors: cbar(X) = [c(t1), c(t2)] for each population
cflat_x0 = [c_of(x0(1)), c_of(x0(2))];
cflat_x1 = [c_of(x1(1)), c_of(x1(2))];
cflat_x2 = [c_of(x2(1)), c_of(x2(2))];
% 
tol = 1e-4;
inactive = cflat_x0 < -tol;

active_mask = ~inactive;

cflat_x0 = cflat_x0(active_mask);
cflat_x1 = cflat_x1(active_mask);
cflat_x2 = cflat_x2(active_mask);


% Directional derivatives d (r x 1)
xi = [x1; x2];         % r x d (2x2)
diffs = xi - x0;       % r x d
norms = vecnorm(diffs, 2, 2); % r x 1
d_vec = ([chv_x1; chv_x2] - chv_x0) ./ norms; % r x 1

% Direction matrix V (d x r)
V = (diffs ./ norms)'; % d x r (2x2)

% Constraint difference matrix M (mu*p x r)
% M_i = (cbar(X_i) - cbar(X_0)) / ||X_i - X_0||
M = (([cflat_x1; cflat_x2] - cflat_x0) ./ norms)'; % (mu*p) x r (2x2)

% Newton system: [V'V+I M'; M 0] [lambda; mu] = [d; -cbar(X0)]
% The key difference from unconstrained GSA is the Newton correction
% -cbar(X0) on the right-hand side, which drives infeasible solutions
% toward the constraint boundary
r_dim = size(V, 2);
np = size(M, 1);
A = [V'*V, M'; M, zeros(np)];
b_rhs = [d_vec; -cflat_x0'];

% Solve via pseudo-inverse (robust to singular saddle-point systems)
vec = pinv(A) * b_rhs;
lambda = vec(1:r_dim);

% Search direction nu_S*
v_raw = V * lambda;
nu_star = v_raw / norm(v_raw);

%% Arrows
% Red arrow: GSA search direction nu_S*
arrow_len = 0.2;
quiver(x0(1), x0(2), nu_star(1)*arrow_len, nu_star(2)*arrow_len, 0, ...
    'Color', 'r', 'LineWidth', 5, 'MaxHeadSize', 1);

% Green arrow: red -> green
quiver(x0(1), x0(2), (x1(1)-x0(1))*0.8, (x1(2)-x0(2))*0.8, 0, ...
    'Color', [0 0.8 0], 'LineWidth', 3, 'MaxHeadSize', 1);

% Blue arrow: red -> blue
quiver(x0(1), x0(2), (x2(1)-x0(1))*0.8, (x2(2)-x0(2))*0.8, 0, ...
    'Color', [0.3 0.75 0.93], 'LineWidth', 3, 'MaxHeadSize', 1);



%% Population markers (drawn last so they appear on top)
% Red population
plot(x0(1), x0(2), 'ro', 'MarkerSize', 26, ...
    'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

% Green population
plot(x1(1), x1(2), 'gs', 'MarkerSize', 26, ...
    'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

% Blue population
plot(x2(1), x2(2), '^', 'Color', [0.3 0.75 0.93], 'MarkerSize', 26, ...
    'MarkerFaceColor', [0.3 0.75 0.93], 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

% Purple colormap (same as unconstrained version)
power_factor = 3;
query_points = linspace(0, 1, 256)'.^power_factor;
cmap = interp1([0; 0.5; 1], [1 1 1; 0.7 0.3 0.7; 0.3 0 0.5], query_points);

colormap(cmap);
colorbar('off');

% Formatting: labels only, no title, no legend, no ticks
xlabel('$t^{(1)}$', 'Interpreter', 'latex');
ylabel('$t^{(2)}$', 'Interpreter', 'latex', 'Rotation', 0);
set(gca, 'XTick', [], 'YTick', []);
xlim([0 0.5]);
ylim([0.5 1]);
hold off;

% filename = 'ProduceImage/images/CHVSpaceGSA.png';
% exportgraphics(gcf, filename, 'Resolution', 300);
% close(gcf);