function drawArrow3D(p0, vec, color, lw, head_len, head_rad)
% Draw a 3D arrow with a cone-shaped head of fixed dimensions.
%   p0       : 1x3 origin
%   vec      : 1x3 displacement (arrow points from p0 to p0+vec)
%   color    : 1x3 RGB
%   lw       : shaft line width
%   head_len : axial length of the conical arrowhead
%   head_rad : base radius of the conical arrowhead

L = norm(vec);
if L == 0, return; end
u  = vec(:) / L;
p1 = p0(:) + vec(:);
shaft_end = p1 - head_len * u;

% Shaft
plot3([p0(1) shaft_end(1)], [p0(2) shaft_end(2)], [p0(3) shaft_end(3)], ...
    'Color', color, 'LineWidth', lw);

% Orthonormal basis perpendicular to u
if abs(u(3)) < 0.9
    w = cross(u, [0; 0; 1]);
else
    w = cross(u, [1; 0; 0]);
end
w  = w / norm(w);
v2 = cross(u, w);

% Circular base of the cone
nseg  = 28;
theta = linspace(0, 2*pi, nseg);
base  = shaft_end + head_rad * (w * cos(theta) + v2 * sin(theta));

% Lateral surface: strip of triangles from base ring to apex
X = [base(1,:); repmat(p1(1), 1, nseg)];
Y = [base(2,:); repmat(p1(2), 1, nseg)];
Z = [base(3,:); repmat(p1(3), 1, nseg)];
surf(X, Y, Z, 'FaceColor', color, 'EdgeColor', 'none', ...
    'FaceLighting', 'none', 'AmbientStrength', 1);

% Base cap
fill3(base(1,:), base(2,:), base(3,:), color, 'EdgeColor', 'none');
end
