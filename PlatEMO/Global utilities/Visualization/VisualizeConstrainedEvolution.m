%% Animation Visualization Function
function VisualizeConstrainedEvolution(viz_data, feasibility_map, Problem)
    % Create figure for animation with slider
    fig = figure('Position', [100, 100, 1000, 800], ...
                 'Name', 'NSGA-II + CHVGSA with Feasibility Regions');
    
    % Get number of iterations
    num_iters = length(viz_data.populations);
    
    % Create slider panel
    slider_panel = uipanel('Position', [0.1, 0.01, 0.8, 0.04]);
    iteration_slider = uicontrol('Parent', slider_panel, 'Style', 'slider', ...
                                 'Units', 'normalized', ...
                                 'Position', [0.1, 0.2, 0.6, 0.6], ...
                                 'Min', 1, 'Max', max(1, num_iters), ...
                                 'Value', min(1, num_iters), ...
                                 'SliderStep', [1/max(1, num_iters-1), 4/max(1, num_iters-1)]);
    
    iter_text = uicontrol('Parent', slider_panel, 'Style', 'text', ...
                         'Units', 'normalized', ...
                         'Position', [0.75, 0.2, 0.15, 0.6], ...
                         'String', sprintf('Iter: %d', min(1, num_iters)), ...
                         'FontSize', 10, 'Tag','NoEnlarge');

    
    % Add play/pause button
    play_button = uicontrol('Parent', slider_panel, 'Style', 'pushbutton', ...
                           'Units', 'normalized', ...
                           'Position', [0.92, 0.2, 0.06, 0.6], ...
                           'String', '▶', 'FontSize', 12, ...
                           'UserData', struct('playing', false));
    
    % Main axes for visualization
    ax = axes('Position', [0.1, 0.15, 0.85, 0.75]);
    
    % Setup play button callback
    play_button.Callback = @(src, ~) playAnimation(src, iteration_slider, num_iters);
    
    % Setup slider callback
    iteration_slider.Callback = @(src, ~) updateConstrainedPlot(src, ax, viz_data, ...
                                          feasibility_map, iter_text, Problem);
    
    % Initial plot
    updateConstrainedPlot(iteration_slider, ax, viz_data, feasibility_map, ...
                         iter_text, Problem);
end

function updateConstrainedPlot(slider, ax, viz_data, feasibility_map, iter_text, Problem)
    % Get current iteration
    current_iter = round(slider.Value);
    
    % Check number of objectives and route to appropriate visualization
    if Problem.M == 2
        updateConstrainedPlot2D(slider, ax, viz_data, feasibility_map, iter_text, Problem, current_iter);
    elseif Problem.M == 3
        updateConstrainedPlot3D(slider, ax, viz_data, feasibility_map, iter_text, Problem, current_iter);
    else
        error('Visualization only supports 2 or 3 objectives. Got M=%d', Problem.M);
    end
end

function updateConstrainedPlot2D(slider, ax, viz_data, feasibility_map, iter_text, Problem, current_iter)
    % Original 2D implementation
    % Clear and setup axes
    cla(ax);
    hold(ax, 'on');
    grid(ax, 'on');
    xlabel(ax, 'Objective 1', 'FontSize', 12);
    ylabel(ax, 'Objective 2', 'FontSize', 12);
    title(ax, sprintf('Constrained Evolution at Iteration %d', current_iter), ...
          'FontSize', 14, 'FontWeight', 'bold');
    
    %% Plot feasibility regions (if we have sampled points)
    [feas_obj, infeas_obj] = feasibility_map.getFeasibilityRegions();
    
    if ~isempty(feas_obj) || ~isempty(infeas_obj)
        % Create alpha shape or convex hull for feasible region
        if ~isempty(feas_obj) && size(feas_obj, 1) > 3
            % Plot feasible region in light green
            scatter(ax, feas_obj(:, 1), feas_obj(:, 2), 20, ...
                       'g', 'filled', 'MarkerFaceAlpha', 0.3);
        end
        
        if ~isempty(infeas_obj) && size(infeas_obj, 1) > 3
            % Plot infeasible region in light red
            scatter(ax, infeas_obj(:, 1), infeas_obj(:, 2), 20, ...
                       'r', 'filled', 'MarkerFaceAlpha', 0.3);
        end
    end
    
    %% Plot population evolution
    if current_iter <= length(viz_data.populations) && ~isempty(viz_data.populations{current_iter})
        pop = viz_data.populations{current_iter};
        pop_objs = pop.objs;

        % Determine feasibility of current population
        pop_feasible = all(pop.cons <= 0, 2)';

        % Plot trajectory of previous iterations (faded)
        for i = 1:min(current_iter-1, length(viz_data.populations))
            if ~isempty(viz_data.populations{i})
                prev_pop = viz_data.populations{i};
                prev_objs = prev_pop.objs;
                alpha_factor = 0.1 + 0.3 * (i / current_iter);
                
                scatter(ax, prev_objs(:, 1), prev_objs(:, 2), 20, ...
                       [0.7, 0.7, 0.7], 'filled', ...
                       'MarkerFaceAlpha', alpha_factor);
            end
        end
        
        % Plot current population with different markers for feasible/infeasible
        feas_idx = pop_feasible;
        lightblue = [0.22, 0.64, 0.88];
        if any(feas_idx)
            scatter(ax, pop_objs(feas_idx, 1), pop_objs(feas_idx, 2), ...
                   100, lightblue, 'o', 'filled', ...
                   'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
        end
        
        % Infeasible solutions
        infeas_idx = ~pop_feasible;
        if any(infeas_idx)
            scatter(ax, pop_objs(infeas_idx, 1), pop_objs(infeas_idx, 2), ...
                   100, lightblue, 'x', 'LineWidth', 2);
        end
        
        %% Plot GSA transition if available
        if current_iter <= length(viz_data.GSA_pops) && ...
           ~isempty(fieldnames(viz_data.GSA_pops{current_iter}))

            pre = viz_data.GSA_pops{current_iter}.pre;
            post = viz_data.GSA_pops{current_iter}.post;

            X0 = [pre{:}];
            X1 = [post{:}];

            % Plot transition arrows
            X0_objs = X0.objs;
            X1_objs = X1.objs;

            %% Arrows
            num_arrows = numel(post{1});
            num_points = numel(pre);

            alphas = linspace(0.4, 1, num_arrows).^2;
            base = [0 0 0];
            bg = get(ax,'Color');
            if (ischar(bg) && strcmp(bg,'none')) || (isstring(bg) && bg=="none")
                bg = get(ancestor(ax,'figure'),'Color');
            end

            for j = 1:num_points
                p0 = pre{j}.objs;
                target_objs = post{j}.objs;
                for k = 1:num_arrows
                    a   = alphas(k);
                    col = (1-a).*bg + a.*base;

                    p1 = target_objs(k, :);
                    u = p1(1) - p0(1);
                    v = p1(2) - p0(2);
                    quiver(ax, p0(1), p0(2), u, v, ...
                          0, 'Color', col, 'LineWidth', 2, ...
                          'MaxHeadSize', 0.01, 'ShowArrowHead', 'off');
                end
            end
            
            % Highlight X0 (before GSA) in red
            scatter(ax, X0_objs(:, 1), X0_objs(:, 2), 80, ...
                   'r', 's', 'filled', 'MarkerEdgeColor', 'k', ...
                   'LineWidth', 1, 'MarkerFaceAlpha', 0.75, 'MarkerEdgeAlpha', 0.25);
            
            % Highlight X1 (after GSA) in green
            scatter(ax, X1_objs(:, 1), X1_objs(:, 2), 80, ...
                   'g', '^', 'filled', 'MarkerEdgeColor', 'k', ...
                   'LineWidth', 1);
        end
    end
    
    %% Add eta value and constraint info
    if current_iter <= length(viz_data.eta_values) && viz_data.eta_values(current_iter) > 0
        text(ax, 0.02, 0.98, sprintf('η: %.5f', viz_data.eta_values(current_iter)), ...
             'Units', 'normalized', 'VerticalAlignment', 'top', ...
             'FontSize', 11, 'FontWeight', 'bold', ...
             'BackgroundColor', 'w', 'EdgeColor', 'k');
    end
    
    % Add feasibility region legend
    text(ax, 0.02, 0.90, 'Regions:', 'Units', 'normalized', ...
         'VerticalAlignment', 'top', 'FontSize', 10, 'FontWeight', 'bold');
    text(ax, 0.02, 0.84, '■ Green: Feasible', 'Units', 'normalized', ...
         'VerticalAlignment', 'top', 'FontSize', 9, 'Color', [0, 0.6, 0]);
    text(ax, 0.02, 0.78, '■ Red: Infeasible', 'Units', 'normalized', ...
         'VerticalAlignment', 'top', 'FontSize', 9, 'Color', [0.8, 0, 0]);
    
    %% Add legend
    h_handles = [];
    h_labels = {};
    
    % Population markers
    h1 = scatter(ax, NaN, NaN, 80, 'b', 'o', 'filled', 'MarkerEdgeColor', 'k');
    h_handles(end+1) = h1;
    h_labels{end+1} = 'Feasible Sol.';
    
    h2 = scatter(ax, NaN, NaN, 80, 'b', 'x', 'LineWidth', 2);
    h_handles(end+1) = h2;
    h_labels{end+1} = 'Infeasible Sol.';
    
    % GSA markers if present
    if current_iter <= length(viz_data.GSA_pops) && ...
       ~isempty(fieldnames(viz_data.GSA_pops{current_iter}))
        h3 = scatter(ax, NaN, NaN, 100, 'r', 's', 'filled');
        h_handles(end+1) = h3;
        h_labels{end+1} = 'X0 (Pre-GSA)';
        
        h4 = scatter(ax, NaN, NaN, 120, 'g', '^', 'filled');
        h_handles(end+1) = h4;
        h_labels{end+1} = 'X1 (Post-GSA)';
    end
    
    legend(ax, h_handles, h_labels, 'Location', 'best');
    EnlargeFont();

    % Update iteration text
    iter_text.String = sprintf('Iter: %d', current_iter);
end

function setup3DNavigation(ax)
    % Setup intuitive 3D navigation controls
    % LMB: Rotate
    % Mouse wheel: Zoom
    % MMB or Shift+LMB: Pan
    % RMB: Context menu (or alternative zoom)
    
    fig = ancestor(ax, 'figure');
    
    % Store initial view parameters
    setappdata(ax, 'MousePressed', false);
    setappdata(ax, 'MouseButton', 'none');
    setappdata(ax, 'LastMousePos', [0 0]);
    setappdata(ax, 'InitialView', get(ax, 'View'));
    
    % Disable default interactions first
    rotate3d(ax, 'off');
    zoom(ax, 'off');
    pan(ax, 'off');
    
    % Set up custom callbacks
    set(fig, 'WindowButtonDownFcn', @(src, evt) mouseDown(src, evt, ax));
    set(fig, 'WindowButtonUpFcn', @(src, evt) mouseUp(src, evt, ax));
    set(fig, 'WindowButtonMotionFcn', @(src, evt) mouseMove(src, evt, ax));
    set(fig, 'WindowScrollWheelFcn', @(src, evt) mouseScroll(src, evt, ax));
    
    % Add keyboard shortcuts
    set(fig, 'KeyPressFcn', @(src, evt) keyPress(src, evt, ax));
end

function mouseDown(fig, ~, ax)
    setappdata(ax, 'MousePressed', true);
    
    % Get mouse button type
    switch get(fig, 'SelectionType')
        case 'normal'  % Left click
            if isShiftPressed()
                setappdata(ax, 'MouseButton', 'pan');
            else
                setappdata(ax, 'MouseButton', 'rotate');
            end
        case 'extend'  % Middle click (or Shift+Left)
            setappdata(ax, 'MouseButton', 'pan');
        case 'alt'     % Right click
            setappdata(ax, 'MouseButton', 'zoom');
        otherwise
            setappdata(ax, 'MouseButton', 'none');
    end
    
    % Store initial mouse position
    mouse_pos = get(fig, 'CurrentPoint');
    setappdata(ax, 'LastMousePos', mouse_pos);
    setappdata(ax, 'InitialCameraPos', get(ax, 'CameraPosition'));
    setappdata(ax, 'InitialCameraTarget', get(ax, 'CameraTarget'));
end

function mouseUp(~, ~, ax)
    setappdata(ax, 'MousePressed', false);
    setappdata(ax, 'MouseButton', 'none');
end

function mouseMove(fig, ~, ax)
    if ~getappdata(ax, 'MousePressed')
        return;
    end
    
    mouse_pos = get(fig, 'CurrentPoint');
    last_pos = getappdata(ax, 'LastMousePos');
    delta = mouse_pos - last_pos;
    
    button = getappdata(ax, 'MouseButton');

    switch button
        case 'rotate'
            % Get current camera properties
            cam_pos = get(ax, 'CameraPosition');
            cam_target = get(ax, 'CameraTarget');
            current_view = get(ax, 'View');
            cam_up = get(ax, 'CameraUpVector');
            
            % Calculate rotation around target
            diff = cam_pos - cam_target;
            radius = norm(diff);  % Preserve the distance
            
            % Sensitivity factors
            azimuth_sensitivity = 0.5;
            elevation_sensitivity = 0.5;
            
            % Get current view angles
            current_view = get(ax, 'View');
            
            % Update angles based on mouse movement
            new_azimuth = current_view(1) - delta(1) * azimuth_sensitivity;
            new_elevation = current_view(2) + delta(2) * elevation_sensitivity;
            
            % Limit elevation to prevent flipping
            new_elevation = max(-90, min(90, new_elevation));
            
            % Convert view angles to radians (MATLAB view uses different convention)
            az_rad = (90 - new_azimuth) * pi/180;  % Convert to mathematical angle
            el_rad = new_elevation * pi/180;
            
            % Calculate new camera position maintaining the same radius
            new_x = cam_target(1) + radius * cos(el_rad) * cos(az_rad);
            new_y = cam_target(2) + radius * cos(el_rad) * sin(az_rad);
            new_z = cam_target(3) + radius * sin(el_rad);
            
            % Set the new camera position
            set(ax, 'View', [new_azimuth, new_elevation]);
        case 'pan'
            % Pan with middle mouse button or Shift+LMB
            cam_pos = get(ax, 'CameraPosition');
            cam_target = get(ax, 'CameraTarget');
            cam_up = get(ax, 'CameraUpVector');
            current_view = get(ax, 'View');
            
            % Calculate right and up vectors in camera space
            forward = cam_target - cam_pos;
            forward = forward / norm(forward);
            right = cross(forward, cam_up);
            right = right / norm(right);
            up = cross(right, forward);
            
            % Pan sensitivity based on camera distance
            % dist = norm(cam_target - cam_pos);
            pan_sensitivity = 5;
            
            % Calculate pan offset
            pan_offset = right * delta(1) * pan_sensitivity + up * delta(2) * pan_sensitivity;
            
            % Apply pan
            set(ax, 'CameraPosition', cam_pos + pan_offset);
            set(ax, 'CameraTarget', cam_target + pan_offset);
            set(ax, 'View', current_view);
            
        case 'zoom'
            % Zoom with right mouse button drag
            zoom_sensitivity = 0.01;
            zoom_factor = 1 + delta(2) * zoom_sensitivity;
            
            cam_pos = get(ax, 'CameraPosition');
            cam_target = get(ax, 'CameraTarget');
            current_view = get(ax, 'View');
            
            % Zoom by moving camera closer/farther from target
            direction = cam_pos - cam_target;
            new_pos = cam_target + direction * zoom_factor;
            set(ax, 'CameraPosition', new_pos);
            set(ax, 'CameraTarget', cam_target);
            set(ax, 'View', current_view);
    end
    
    setappdata(ax, 'LastMousePos', mouse_pos);
end

function mouseScroll(~, evt, ax)
    % Zoom with mouse wheel (like every sane 3D software!)
    zoom_sensitivity = 0.1;
    zoom_factor = 1 + evt.VerticalScrollCount * zoom_sensitivity;
    
    % Get current camera properties
    cam_pos = get(ax, 'CameraPosition');
    cam_target = get(ax, 'CameraTarget');
    current_view = get(ax, 'View');
    
    % Calculate new camera position (zoom in/out)
    direction = cam_pos - cam_target;
    new_pos = cam_target + direction * zoom_factor;
    
    % Apply zoom
    set(ax, 'CameraPosition', new_pos);
    set(ax, 'CameraTarget', cam_target);
    set(ax, 'View', current_view);

end

function keyPress(~, evt, ax)
    % Keyboard shortcuts for view control
    switch evt.Key
        case 'r'
            % Reset view to initial state
            view(ax, -37.5, 30);
            axis(ax, 'tight');
            
        case 'x'
            % View along X axis
            view(ax, [0, 0]);
            
        case 'y'
            % View along Y axis  
            view(ax, [90, 0]);
            
        case 'z'
            % View along Z axis
            view(ax, [0, 90]);
            
        case 'home'
            % Reset to home view
            view(ax, -37.5, 30);
            axis(ax, 'tight');
    end
end

function pressed = isShiftPressed()
    % Check if Shift key is pressed
    % This is a workaround since MATLAB doesn't directly provide modifier keys
    % in mouse callbacks
    pressed = false;
    try
        % This method works in newer MATLAB versions
        modifiers = get(gcbf, 'CurrentModifier');
        pressed = ismember('shift', modifiers);
    catch
        % Fallback for older versions
        pressed = false;
    end
end

function updateConstrainedPlot3D(slider, ax, viz_data, feasibility_map, iter_text, Problem, current_iter)
    % 3D implementation for 3-objective problems
    
    % Clear and setup 3D axes
    cla(ax);
    hold(ax, 'on');
    grid(ax, 'on');
    
    % Set labels and title
    xlabel(ax, 'Objective 1', 'FontSize', 12);
    ylabel(ax, 'Objective 2', 'FontSize', 12);
    zlabel(ax, 'Objective 3', 'FontSize', 12);
    title(ax, sprintf('3D Constrained Evolution at Iteration %d', current_iter), ...
          'FontSize', 14, 'FontWeight', 'bold');
    
    % Set initial view angle (can be adjusted)
    if ~isappdata(ax, 'ViewInitialized')
        view(ax, -37.5, 30);
        setup3DNavigation(ax);
        setappdata(ax, 'ViewInitialized', true);
    end
    
    %% Plot feasibility regions in 3D
    [feas_obj, infeas_obj] = feasibility_map.getFeasibilityRegions();
    
    if ~isempty(feas_obj) || ~isempty(infeas_obj)
        % For 3D, we need to handle the third objective dimension
        if ~isempty(feas_obj) && size(feas_obj, 1) > 4
            if size(feas_obj, 2) >= 3
                % Plot feasible region as 3D scatter
                scatter3(ax, feas_obj(:, 1), feas_obj(:, 2), feas_obj(:, 3), 15, ...
                        'g', 'filled', 'MarkerFaceAlpha', 0.2);
                
                % % Try to create convex hull for better visualization
                % if size(feas_obj, 1) > 10
                %     try
                %         k = convhull(feas_obj(:, 1), feas_obj(:, 2), feas_obj(:, 3));
                %         trisurf(k, feas_obj(:, 1), feas_obj(:, 2), feas_obj(:, 3), ...
                %                'FaceColor', 'g', 'FaceAlpha', 0.1, 'EdgeAlpha', 0.1);
                %     catch
                %         % If convex hull fails, just use scatter
                %     end
                % end
            end
        end
        
        if ~isempty(infeas_obj) && size(infeas_obj, 1) > 4
            if size(infeas_obj, 2) >= 3
                % Plot infeasible region as 3D scatter
                scatter3(ax, infeas_obj(:, 1), infeas_obj(:, 2), infeas_obj(:, 3), 15, ...
                        'r', 'filled', 'MarkerFaceAlpha', 0.2);
                
                % % Try to create convex hull
                % if size(infeas_obj, 1) > 10
                %     try
                %         k = convhull(infeas_obj(:, 1), infeas_obj(:, 2), infeas_obj(:, 3));
                %         trisurf(k, infeas_obj(:, 1), infeas_obj(:, 2), infeas_obj(:, 3), ...
                %                'FaceColor', 'r', 'FaceAlpha', 0.1, 'EdgeAlpha', 0.1);
                %     catch
                %         % If convex hull fails, just use scatter
                %     end
                % end
            end
        end
    end
    
    %% Plot population evolution in 3D
    if current_iter <= length(viz_data.populations) && ~isempty(viz_data.populations{current_iter})
        pop = viz_data.populations{current_iter};
        pop_objs = pop.objs;
        
        % Check if we have 3 objectives
        if size(pop_objs, 2) < 3
            error('Population does not have 3 objectives for 3D visualization');
        end

        % Determine feasibility of current population
        pop_feasible = all(pop.cons <= 0, 2)';

        % Plot trajectory of previous iterations (faded) with connecting lines
        trajectory_points = [];
        for i = 1:min(current_iter-1, length(viz_data.populations))
            if ~isempty(viz_data.populations{i})
                prev_pop = viz_data.populations{i};
                prev_objs = prev_pop.objs;
                
                if size(prev_objs, 2) >= 3
                    alpha_factor = 0.05 + 0.25 * (i / current_iter);
                    
                    scatter3(ax, prev_objs(:, 1), prev_objs(:, 2), prev_objs(:, 3), ...
                            15, [0.7, 0.7, 0.7], 'filled', ...
                            'MarkerFaceAlpha', alpha_factor);
                    
                    % Store centroid for trajectory line
                    if ~isempty(prev_objs)
                        trajectory_points = [trajectory_points; mean(prev_objs(:, 1:3), 1)];
                    end
                end
            end
        end
        
        % Draw trajectory line through centroids
        if size(trajectory_points, 1) > 1
            plot3(ax, trajectory_points(:, 1), trajectory_points(:, 2), trajectory_points(:, 3), ...
                 'k-', 'LineWidth', 0.5, 'Color', [0.5, 0.5, 0.5, 0.3]);
        end
        
        % Plot current population with different markers for feasible/infeasible
        feas_idx = pop_feasible;
        lightblue = [0.22, 0.64, 0.88];
        
        if any(feas_idx)
            scatter3(ax, pop_objs(feas_idx, 1), pop_objs(feas_idx, 2), pop_objs(feas_idx, 3), ...
                    80, lightblue, 'o', 'filled', ...
                    'MarkerEdgeColor', 'k', 'LineWidth', 1.2);
        end
        
        % Infeasible solutions
        infeas_idx = ~pop_feasible;
        if any(infeas_idx)
            scatter3(ax, pop_objs(infeas_idx, 1), pop_objs(infeas_idx, 2), pop_objs(infeas_idx, 3), ...
                    80, lightblue, 'x', 'LineWidth', 2);
        end
        
        %% Plot GSA transition in 3D if available
        if current_iter <= length(viz_data.GSA_pops) && ...
           ~isempty(fieldnames(viz_data.GSA_pops{current_iter}))

            pre = viz_data.GSA_pops{current_iter}.pre;
            post = viz_data.GSA_pops{current_iter}.post;

            X0 = [pre{:}];
            X1 = [post{:}];

            % Plot transition arrows in 3D
            X0_objs = X0.objs;
            X1_objs = X1.objs;
            
            if size(X0_objs, 2) >= 3 && size(X1_objs, 2) >= 3
                %% 3D Arrows using quiver3
                num_arrows = numel(post{1});
                num_points = numel(pre);

                alphas = linspace(0.3, 1, num_arrows).^2;
                base = [0 0 0];
                bg = get(ax, 'Color');
                if (ischar(bg) && strcmp(bg,'none')) || (isstring(bg) && bg=="none")
                    bg = get(ancestor(ax,'figure'),'Color');
                end

                for j = 1:num_points
                    p0 = pre{j}.objs;
                    target_objs = post{j}.objs;
                    
                    if size(p0, 2) >= 3 && size(target_objs, 2) >= 3
                        for k = 1:num_arrows
                            a   = alphas(k);
                            col = (1-a).*bg + a.*base;

                            p1 = target_objs(k, 1:3);
                            u = p1(1) - p0(1);
                            v = p1(2) - p0(2);
                            w = p1(3) - p0(3);
                            
                            % Draw line instead of quiver3 for better visibility
                            plot3(ax, [p0(1), p1(1)], [p0(2), p1(2)], [p0(3), p1(3)], ...
                                 '-', 'Color', [col, 0.6], 'LineWidth', 1.5);
                            
                            % Add small arrow head manually
                            arrow_scale = 0.05;
                            arrow_dir = [u, v, w] / norm([u, v, w]) * arrow_scale;
                            if ~any(isnan(arrow_dir))
                                % Create simple arrow head
                                arrow_end = p1 - arrow_dir;
                                plot3(ax, [arrow_end(1), p1(1)], ...
                                     [arrow_end(2), p1(2)], ...
                                     [arrow_end(3), p1(3)], ...
                                     '-', 'Color', col, 'LineWidth', 2);
                            end
                        end
                    end
                end
                
                % Highlight X0 (before GSA) in red - use cubes
                scatter3(ax, X0_objs(:, 1), X0_objs(:, 2), X0_objs(:, 3), 100, ...
                        'r', 's', 'filled', 'MarkerEdgeColor', 'k', ...
                        'LineWidth', 1, 'MarkerFaceAlpha', 0.8);
                
                % Highlight X1 (after GSA) in green - use pyramids
                scatter3(ax, X1_objs(:, 1), X1_objs(:, 2), X1_objs(:, 3), 120, ...
                        'g', '^', 'filled', 'MarkerEdgeColor', 'k', ...
                        'LineWidth', 1, 'MarkerFaceAlpha', 0.9);
            end
        end
    end
    
    %% Add eta value and constraint info (positioned for 3D view)
    if current_iter <= length(viz_data.eta_values) && viz_data.eta_values(current_iter) > 0
        text(ax, 0.02, 0.98, sprintf('η: %.5f', viz_data.eta_values(current_iter)), ...
             'Units', 'normalized', 'VerticalAlignment', 'top', ...
             'FontSize', 11, 'FontWeight', 'bold', ...
             'BackgroundColor', 'w', 'EdgeColor', 'k');
    end
    
    % Add feasibility region legend
    text(ax, 0.02, 0.92, 'Regions:', 'Units', 'normalized', ...
         'VerticalAlignment', 'top', 'FontSize', 10, 'FontWeight', 'bold');
    text(ax, 0.02, 0.88, '■ Green: Feasible', 'Units', 'normalized', ...
         'VerticalAlignment', 'top', 'FontSize', 9, 'Color', [0, 0.6, 0]);
    text(ax, 0.02, 0.84, '■ Red: Infeasible', 'Units', 'normalized', ...
         'VerticalAlignment', 'top', 'FontSize', 9, 'Color', [0.8, 0, 0]);
    
    % Add view controls hint
    text(ax, 0.02, 0.78, 'LMB: Rotate | Wheel: Zoom | MMB/Shift+LMB: Pan | R: Reset', 'Units', 'normalized', ...
         'VerticalAlignment', 'top', 'FontSize', 8, 'Color', [0.3, 0.3, 0.3], 'FontWeight', 'bold');
    
    %% Add legend for 3D plot
    h_handles = [];
    h_labels = {};
    
    % Population markers
    h1 = scatter3(ax, NaN, NaN, NaN, 80, 'b', 'o', 'filled', 'MarkerEdgeColor', 'k');
    h_handles(end+1) = h1;
    h_labels{end+1} = 'Feasible Sol.';
    
    h2 = scatter3(ax, NaN, NaN, NaN, 80, 'b', 'x', 'LineWidth', 2);
    h_handles(end+1) = h2;
    h_labels{end+1} = 'Infeasible Sol.';
    
    % GSA markers if present
    if current_iter <= length(viz_data.GSA_pops) && ...
       ~isempty(fieldnames(viz_data.GSA_pops{current_iter}))
        h3 = scatter3(ax, NaN, NaN, NaN, 100, 'r', 's', 'filled');
        h_handles(end+1) = h3;
        h_labels{end+1} = 'X0 (Pre-GSA)';
        
        h4 = scatter3(ax, NaN, NaN, NaN, 120, 'g', '^', 'filled');
        h_handles(end+1) = h4;
        h_labels{end+1} = 'X1 (Post-GSA)';
    end
    
    legend(ax, h_handles, h_labels, 'Location', 'northeast');
    
    % Set axis properties for better 3D visualization
    axis(ax, 'vis3d');
    box(ax, 'on');
    
    % Adjust lighting for 3D
    lighting(ax, 'gouraud');
    light('Position', [1 1 1], 'Style', 'infinite');
    light('Position', [-1 -1 -1], 'Style', 'infinite', 'Color', [0.3 0.3 0.3]);
    
    % Update iteration text
    iter_text.String = sprintf('Iter: %d', current_iter);
end

function playAnimation(button, slider, num_iters)
    % Toggle play/pause state
    user_data = get(button, 'UserData');
    user_data.playing = ~user_data.playing;
    set(button, 'UserData', user_data);
    
    if user_data.playing
        set(button, 'String', '❚❚');  % Pause symbol
        
        % Play animation
        current_val = get(slider, 'Value');
        for i = current_val:num_iters
            if ~get(button, 'UserData').playing
                break;
            end
            set(slider, 'Value', i);
            
            % Trigger slider callback
            callback = get(slider, 'Callback');
            callback(slider, []);
            
            pause(0.1);  % Animation speed
        end
        
        % Reset button when done
        user_data.playing = false;
        set(button, 'UserData', user_data);
        set(button, 'String', '▶');
    else
        set(button, 'String', '▶');  % Play symbol
    end
end