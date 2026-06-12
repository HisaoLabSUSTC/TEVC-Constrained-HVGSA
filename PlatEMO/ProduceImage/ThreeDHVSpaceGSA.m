% 3D Hypervolume landscape surface with GSA search direction visualization
% Grid-sample pairs (t1, t2) and compute HV for each 2-solution population

n = 400;
t1_grid = linspace(0, 1, n);
t2_grid = linspace(0, 1, n);
[T1, T2] = meshgrid(t1_grid, t2_grid);

% Objective values for solution 1 (parameterized by t1)
F1_1 = T1 + 0.25 + 0.5 * cos(4*pi*T1);
F2_1 = 1.25 - T1 + 0.5 * cos(4*pi*T1);

% Objective values for solution 2 (parameterized by t2)
F1_2 = T2 + 0.25 + 0.5 * cos(4*pi*T2);
F2_2 = 1.25 - T2 + 0.5 * cos(4*pi*T2);

% Hypervolume via inclusion-exclusion of two rectangles to ref
ref = [2, 2];
HV = max(0, ref(1)-F1_1) .* max(0, ref(2)-F2_1) + ...
     max(0, ref(1)-F1_2) .* max(0, ref(2)-F2_2) - ...
     max(0, ref(1)-max(F1_1,F1_2)) .* max(0, ref(2)-max(F2_1,F2_2));

% Create figure
PreprocessProductionImage(0.25, 1, 8.8);

% Surface mesh
surf(T1, T2, HV, 'EdgeColor', 'none', 'FaceAlpha', 0.5);
hold on;

%% GSA computation
x0 = [0.33, 0.68]; % Red (iterate)
x1 = [0.22, 0.71]; % Green (neighbor)
x2 = [0.37, 0.62]; % Blue (neighbor)

% Population positions in decision space
% x0 = [0.33, 0.68]; % Red (iterate)
% x1 = [0.14, 0.65]; % Green (neighbor)
% x2 = [0.35, 0.87]; % Blue (neighbor)

% Objective function helpers
f1_of = @(t) t + 0.25 + 0.5*cos(4*pi*t);
f2_of = @(t) 1.25 - t + 0.5*cos(4*pi*t);

% HV via inclusion-exclusion for a 2-solution population
hv_of = @(t) max(0,ref(1)-f1_of(t(1)))*max(0,ref(2)-f2_of(t(1))) + ...
             max(0,ref(1)-f1_of(t(2)))*max(0,ref(2)-f2_of(t(2))) - ...
             max(0,ref(1)-max(f1_of(t(1)),f1_of(t(2))))*max(0,ref(2)-max(f2_of(t(1)),f2_of(t(2))));

hv_x0 = hv_of(x0);
hv_x1 = hv_of(x1);
hv_x2 = hv_of(x2);

% Directional derivatives
xi = [x1; x2];         % r x d (2x2)
hv_xi = [hv_x1; hv_x2]; % r x 1
diffs = xi - x0;       % r x d
norms = vecnorm(diffs, 2, 2); % r x 1
d_vec = (hv_xi - hv_x0) ./ norms; % r x 1

% Direction matrix V (d x r)
V = (diffs ./ norms)'; % d x r (2x2)

% Normal equations: (V'V + I) lambda = d
lambda = (V'*V + eye(size(V,2))) \ d_vec;

% Search direction nu_S*
v_raw = V * lambda;
nu_star = v_raw / norm(v_raw);

%% Arrows (3D: on the HV surface)
% Compute HV at arrow endpoints for z-coordinates
arrow_scale = 0.8;

% Green arrow vector: red -> green (on surface)
dx_g = (x1(1)-x0(1))*arrow_scale;
dy_g = (x1(2)-x0(2))*arrow_scale;
dz_g = (hv_x1 - hv_x0)*arrow_scale;

% Blue arrow vector: red -> blue (on surface)
dx_b = (x2(1)-x0(1))*arrow_scale;
dy_b = (x2(2)-x0(2))*arrow_scale;
dz_b = (hv_x2 - hv_x0)*arrow_scale;

% Hyperplane spanned by green and blue displacement vectors (drawn first, arrows on top)
plane_extent = [-0.5, 1.5];
[S_p, T_p] = meshgrid(linspace(plane_extent(1), plane_extent(2), 2), ...
                      linspace(plane_extent(1), plane_extent(2), 2));
PX = x0(1) + S_p*dx_g + T_p*dx_b;
PY = x0(2) + S_p*dy_g + T_p*dy_b;
PZ = hv_x0 + S_p*dz_g + T_p*dz_b;
surf(PX, PY, PZ, 'FaceColor', [0.98 0.78 0.25], 'EdgeColor', [0.75 0.55 0.1], ...
    'FaceAlpha', 0.50, 'LineStyle', '-');

% Plane unit normal (oriented upward), used to lift arrows slightly above the plane
n_plane = cross([dx_g dy_g dz_g], [dx_b dy_b dz_b]);
n_plane = n_plane / norm(n_plane);
if n_plane(3) < 0, n_plane = -n_plane; end
lift = 0.015 * n_plane;        % small offset above hyperplane
origin3 = [x0(1), x0(2), hv_x0] + lift;

% Fixed arrowhead dimensions (independent of vector length)
head_len = 0.2;
head_rad = 0.01;

% Red arrow: GSA search direction nu_S* (z-component on the hyperplane)
arrow_len = 0.2;
nx = nu_star(1)*arrow_len;
ny = nu_star(2)*arrow_len;
% Express (nx, ny) in the basis of the green/blue displacement vectors
st = [dx_g, dx_b; dy_g, dy_b] \ [nx; ny];
dz_r = st(1)*dz_g + st(2)*dz_b;

% Draw arrows with proper 3D cone heads
drawArrow3D(origin3, [dx_g, dy_g, dz_g], [0 0.8 0],      3, head_len, head_rad);
drawArrow3D(origin3, [dx_b, dy_b, dz_b], [0.3 0.75 0.93],3, head_len, head_rad);
drawArrow3D(origin3, [nx,   ny,   dz_r] * 0.4, [1 0 0],        4, head_len, head_rad);

%% Population markers (drawn last so they appear on top)
% Red population
plot3(x0(1), x0(2), hv_x0, 'ro', 'MarkerSize', 26, ...
    'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

% Green population
plot3(x1(1), x1(2), hv_x1, 'gs', 'MarkerSize', 26, ...
    'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

% Blue population
plot3(x2(1), x2(2), hv_x2, '^', 'Color', [0.3 0.75 0.93], 'MarkerSize', 26, ...
    'MarkerFaceColor', [0.3 0.75 0.93], 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

% Purple colormap (same as 2D version)
power_factor = 1.4;
query_points = linspace(0, 1, 256)'.^power_factor;
cmap = interp1([0; 0.5; 1], [1 1 1; 0.7 0.3 0.7; 0.3 0 0.5], query_points);

colormap(cmap);
colorbar('off');

% Formatting
xlabel('$t^{(1)}$', 'Interpreter', 'latex', 'position', [0.2190 0.4899 0.1836]);
ylabel('$t^{(2)}$', 'Interpreter', 'latex', 'position', [0.5146 0.7487 -0.0967]);
zlabel('HV', 'Interpreter', 'latex', 'position', [-0.0107 0.5112 2.1886]);
set(gca, 'XTick', [], 'YTick', [], 'ZTick', []);
xlim([0 0.5]);
ylim([0.5 1]);
zlim([0 4])
% zlim
view([75 50]);
hold off;

filename = 'ProduceImage/images/3DHVSpaceGSA-1.png';
exportgraphics(gcf, filename, 'Resolution', 500);
% exportgraphics(gcf, filename, 'ContentType', 'vector');
close(gcf);