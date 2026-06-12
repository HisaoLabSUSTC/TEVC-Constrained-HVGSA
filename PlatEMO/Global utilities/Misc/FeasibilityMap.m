%% Simplified Feasibility Map Class
classdef FeasibilityMap < handle
    properties
        Problem
        sample_radius       % Radius for sampling around solutions
        num_samples_per_sol % Number of samples per solution (default: Problem.D * 2)
        sampled_points      % Stores sampled decision vectors
        objective_points    % Stores corresponding objective vectors
        feasibility_status  % Stores feasibility (1 = feasible, 0 = infeasible)
    end
    
    methods
        function obj = FeasibilityMap(Problem, sample_radius, samples_multiplier)
            % Constructor
            % Problem: the optimization problem
            % sample_radius: radius in decision space for sampling
            % samples_multiplier: multiplier for number of samples (default 2)
            
            obj.Problem = Problem;
            obj.sample_radius = sample_radius;
            
            if nargin < 3
                samples_multiplier = 2;
            end
            obj.num_samples_per_sol = Problem.D * samples_multiplier;
            
            % Initialize storage
            obj.sampled_points = [];
            obj.objective_points = [];
            obj.feasibility_status = [];
        end
        
        function updateWithSolutions(obj, solutions)
            if isempty(solutions)
                return;
            end

            Problem = obj.Problem;
            
            % Get decision vectors of solutions
            sol_decs = solutions.decs;
            
            % Sample around each solution
            new_samples = [];
            for i = 1:size(sol_decs, 1)
                % Generate random samples around this solution
                samples = obj.generateSamplesAroundPoint(sol_decs(i,:));
                new_samples = [new_samples; samples];
            end
            
            % Remove duplicates from new samples
            if ~isempty(new_samples)
                new_samples = unique(new_samples, 'rows');
                
                % Remove samples we've already evaluated
                if ~isempty(obj.sampled_points)
                    % Use tolerance for comparison to handle numerical issues
                    tol = 1e-10;
                    new_idx = [];
                    for j = 1:size(new_samples, 1)
                        diffs = abs(obj.sampled_points - new_samples(j,:));
                        if ~any(all(diffs < tol, 2))
                            new_idx = [new_idx; j];
                        end
                    end
                    new_samples = new_samples(new_idx, :);
                end
                
                % Evaluate new samples
                if ~isempty(new_samples)
                    evaluated = obj.Problem.Evaluation(new_samples);
                    
                    % Store results
                    obj.sampled_points = [obj.sampled_points; new_samples];
                    obj.objective_points = [obj.objective_points; evaluated.objs];
                    
                    % Determine feasibility (constraint violation <= 0 means feasible)
                    if isempty(evaluated.cons)
                        % Unconstrained problem - all feasible
                        new_feasibility = ones(size(new_samples, 1), 1);
                    else
                        new_feasibility = all(evaluated.cons <= 0, 2);
                    end
                    obj.feasibility_status = [obj.feasibility_status; new_feasibility];
                end
            end
        end
        
        function samples = generateSamplesAroundPoint(obj, point)
            % Generate random samples around a given point
            % point: 1×D vector representing a solution in decision space (original scale)
            % Internally normalizes to [0,1] for scale-invariant sampling
            
            D = obj.Problem.D;
            n_samples = obj.num_samples_per_sol;
            samples = zeros(n_samples, D);
            
            % Get bounds
            lower = obj.Problem.lower(:)';
            upper = obj.Problem.upper(:)';
            
            % Normalize the point to [0, 1] range
            % normalized = (point - lower) / (upper - lower)
            range = upper - lower;
            % Handle case where upper == lower (fixed dimension)
            range(range == 0) = 1;  % Avoid division by zero
            normalized_point = (point - lower) ./ range;
            
            % Ensure sample_radius is valid (should be < 1 for normalized space)
            if obj.sample_radius >= 1
                warning('Sample radius %.2f is >= 1. In normalized space, this may sample outside bounds. Consider using a smaller radius.', obj.sample_radius);
            end
            
            for i = 1:n_samples
                % Generate a random direction in normalized space
                direction = randn(1, D);
                direction = direction / norm(direction);  % Normalize to unit vector
                
                % Random distance within the radius (in normalized space)
                distance = obj.sample_radius * rand();
                
                % Create sample point in normalized space
                normalized_sample = normalized_point + distance * direction;
                
                % Clip to [0, 1] in normalized space
                normalized_sample = max(normalized_sample, 0);
                normalized_sample = min(normalized_sample, 1);
                
                % Transform back to original scale
                sample = lower + normalized_sample .* range;
                
                % Extra safety check to ensure within bounds (handles numerical issues)
                sample = max(sample, lower);
                sample = min(sample, upper);
                
                samples(i, :) = sample;
            end
        end
        
        function [feas_obj, infeas_obj] = getFeasibilityRegions(obj)
            % Return objective points separated by feasibility
            if isempty(obj.feasibility_status)
                feas_obj = [];
                infeas_obj = [];
                return;
            end
            
            feas_idx = obj.feasibility_status == 1;
            feas_obj = obj.objective_points(feas_idx, :);
            infeas_obj = obj.objective_points(~feas_idx, :);
        end
        
        function [feas_dec, infeas_dec] = getFeasibleDecisionPoints(obj)
            % Return decision points separated by feasibility
            % Useful for debugging or further analysis
            if isempty(obj.feasibility_status)
                feas_dec = [];
                infeas_dec = [];
                return;
            end
            
            feas_idx = obj.feasibility_status == 1;
            feas_dec = obj.sampled_points(feas_idx, :);
            infeas_dec = obj.sampled_points(~feas_idx, :);
        end
        
        function stats = getStatistics(obj)
            % Get statistics about the feasibility map
            stats = struct();
            stats.total_samples = length(obj.feasibility_status);
            if stats.total_samples > 0
                stats.num_feasible = sum(obj.feasibility_status == 1);
                stats.num_infeasible = sum(obj.feasibility_status == 0);
                stats.feasibility_ratio = stats.num_feasible / stats.total_samples;
            else
                stats.num_feasible = 0;
                stats.num_infeasible = 0;
                stats.feasibility_ratio = NaN;
            end
        end
        
        function reset(obj)
            % Clear all stored data
            obj.sampled_points = [];
            obj.objective_points = [];
            obj.feasibility_status = [];
        end
    end
end