classdef ThreeObjMin < PROBLEM
% <multi> <real> <none> <none>
% Three-objective distance minimization problem with three target points

%------------------------------- Description ------------------------------
% This problem minimizes the Euclidean distances to three target points:
% Target 1: (1, 1)
% Target 2: (9, 1) 
% Target 3: (5, 8)
%
% Decision variables: x1, x2 (2D coordinates)
% Objectives: 
%   f1 = distance to target 1
%   f2 = distance to target 2
%   f3 = distance to target 3
%
% The Pareto optimal set forms a region in 2D space where trade-offs
% between distances to the three targets are optimal.
%--------------------------------------------------------------------------

    properties(Access = private)
        targets = [1, 1;    % Target point 1
                   9, 1;    % Target point 2
                   5, 8];   % Target point 3
    end
    
    methods
        %% Default settings of the problem
        function Setting(obj)
            obj.M = 3;  % Three objectives (distances to three targets)
            obj.D = 2;  % Two decision variables (x1, x2 coordinates)
            
            % Search space bounds (reasonable area containing all targets)
            obj.lower    = [0, 0];
            obj.upper    = [50, 50];
            obj.encoding = ones(1, obj.D);  % Real encoding
        end
        
        %% Calculate objective values (distances to targets)
        function PopObj = CalObj(obj, PopDec)
            N = size(PopDec, 1);  % Number of solutions
            PopObj = zeros(N, obj.M);
            
            % Calculate Euclidean distance to each target point
            for i = 1:obj.M
                diff = PopDec - repmat(obj.targets(i, :), N, 1);
                PopObj(:, i) = sqrt(sum(diff.^2, 2));
            end
        end
        
        %% Generate points on the Pareto front
        function R = GetOptimum(obj, N)
            % For this problem, the Pareto front consists of points that
            % optimally trade-off distances to the three targets.
            % These typically form a region inside the triangle formed by
            % the three target points (the Fermat-Torricelli region).
            
            if N <= 3
                % Return the three target points for small N
                R = obj.CalObj(obj.targets(1:min(N,3), :));
            else
                % Generate approximate Pareto optimal solutions
                % Using a combination of:
                % 1. Points along edges between targets
                % 2. Points in the interior region
                
                points = [];
                
                % Add corner points (each target minimizes one objective)
                points = [points; obj.targets];
                
                % Add points along edges between targets
                n_edge = floor(N/6);
                for i = 1:3
                    j = mod(i, 3) + 1;
                    t = linspace(0.1, 0.9, n_edge)';
                    edge_points = repmat(1-t, 1, 2) .* repmat(obj.targets(i, :), n_edge, 1) + ...
                                  repmat(t, 1, 2) .* repmat(obj.targets(j, :), n_edge, 1);
                    points = [points; edge_points];
                end
                
                % Add interior points (near Fermat point region)
                % The Fermat point minimizes sum of distances
                fermat_point = obj.findFermatPoint();
                n_interior = N - size(points, 1);
                
                if n_interior > 0
                    % Generate points around the Fermat point
                    angles = linspace(0, 2*pi, n_interior+1)';
                    angles(end) = [];
                    radii = 0.5 + 0.5 * rand(n_interior, 1);  % Random radii
                    interior_points = fermat_point + [radii.*cos(angles), radii.*sin(angles)];
                    
                    % Clip to bounds
                    interior_points = max(interior_points, repmat(obj.lower, n_interior, 1));
                    interior_points = min(interior_points, repmat(obj.upper, n_interior, 1));
                    
                    points = [points; interior_points];
                end
                
                % Calculate objectives for all points
                R = obj.CalObj(points(1:N, :));
            end
        end
        
        %% Generate the image of Pareto front for visualization
        function R = GetPF(obj)
            if obj.M == 3
                % Generate a dense set of Pareto optimal points
                N = 500;
                
                % Create a mesh in decision space
                [X1, X2] = meshgrid(linspace(obj.lower(1), obj.upper(1), 30), ...
                                   linspace(obj.lower(2), obj.upper(2), 30));
                points = [X1(:), X2(:)];
                
                % Calculate objectives
                objs = obj.CalObj(points);
                
                % Filter to get approximate Pareto front
                % (This is a simplified approximation)
                [FrontNo, ~] = NDSort(objs, 1);
                pareto_objs = objs(FrontNo == 1, :);
                
                % Return as cell array for 3D visualization
                R = {pareto_objs(:, 1), pareto_objs(:, 2), pareto_objs(:, 3)};
            else
                R = [];
            end
        end
        
        %% Generate the Pareto set in decision space
        function R = GetPS(obj, N)
            % The Pareto set in decision space forms a region
            % This is approximately the region between the three targets
            
            points = [];
            
            % Add the three target points
            points = [points; obj.targets];
            
            % Add the Fermat point
            fermat = obj.findFermatPoint();
            points = [points; fermat];
            
            % Generate points in the triangular region
            n_samples = N - 4;
            if n_samples > 0
                % Use barycentric coordinates for triangle sampling
                r1 = rand(n_samples, 1);
                r2 = rand(n_samples, 1);
                
                % Convert to barycentric
                sqrt_r1 = sqrt(r1);
                bary1 = 1 - sqrt_r1;
                bary2 = sqrt_r1 .* (1 - r2);
                bary3 = sqrt_r1 .* r2;
                
                % Convert to Cartesian coordinates
                triangle_points = bary1 * obj.targets(1, :) + ...
                                 bary2 * obj.targets(2, :) + ...
                                 bary3 * obj.targets(3, :);
                
                points = [points; triangle_points];
            end
            
            R = points(1:min(N, size(points, 1)), :);
        end
    end
    
    methods(Access = private)
        function fermat = findFermatPoint(obj)
            % Find the Fermat point (minimizes sum of distances to targets)
            % Using simple gradient descent
            
            % Start from centroid
            fermat = mean(obj.targets, 1);
            
            % Gradient descent iterations
            alpha = 0.1;  % Learning rate
            for iter = 1:100
                grad = zeros(1, 2);
                for i = 1:3
                    diff = fermat - obj.targets(i, :);
                    dist = norm(diff);
                    if dist > 1e-6
                        grad = grad + diff / dist;
                    end
                end
                fermat = fermat - alpha * grad;
                
                % Reduce learning rate
                alpha = alpha * 0.95;
            end
        end
    end
end