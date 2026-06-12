classdef BayesianAdaStepSizeManager < handle
    % Adaptive Step Size Manager with exploration-exploitation balance
    % Maintains a history of step sizes and their effectiveness
    
    properties
        % Core parameters
        D                   % Problem dimension
        base_eta           % Base step size (sqrt(D))
        min_eta            % Minimum step size (1/sqrt(D))
        
        % History tracking
        eta_history        % History of proposed step sizes
        success_history    % History of successful step sizes
        exhaustion_count   % Count of interpolation exhaustions
        iteration_count    % Current iteration number
        
        % Adaptive parameters
        exploration_prob   % Current exploration probability
        belief_mean        % Mean of belief distribution
        belief_std         % Std of belief distribution
        
        % Memory parameters
        memory_size        % Size of memory buffer
        memory_decay       % Decay factor for old memories
        
        % Exploration parameters
        exploration_decay  % Decay rate for exploration
        exploration_min    % Minimum exploration probability
    end
    
    methods
        function obj = BayesianAdaStepSizeManager(D, options)
            % Constructor
            if nargin < 2
                options = struct();
            end
            
            % Problem-specific parameters
            obj.D = D;
            obj.base_eta = sqrt(D);
            obj.min_eta = 1/sqrt(D);
            
            % Initialize history
            obj.eta_history = [];
            obj.success_history = [];
            obj.exhaustion_count = 0;
            obj.iteration_count = 0;
            
            % Initialize belief distribution
            obj.belief_mean = obj.base_eta;
            obj.belief_std = obj.base_eta / 2;
            
            % Memory parameters
            obj.memory_size = getfield(options, 'memory_size', 50);
            obj.memory_decay = getfield(options, 'memory_decay', 0.95);
            
            % Exploration parameters
            obj.exploration_prob = getfield(options, 'initial_exploration', 0.3);
            obj.exploration_decay = getfield(options, 'exploration_decay', 0.99);
            obj.exploration_min = getfield(options, 'exploration_min', 0.05);
        end
        
        function eta_ub = getNextStepSize(obj, alpha)
            % Get the next upper bound for step size
            % alpha: progress indicator (FE/maxFE)
            
            obj.iteration_count = obj.iteration_count + 1;
            
            % Update exploration probability
            obj.exploration_prob = max(obj.exploration_min, ...
                obj.exploration_prob * obj.exploration_decay);
            
            % Decide whether to explore or exploit
            if rand() < obj.exploration_prob
                % EXPLORATION: Sample from a wider distribution
                eta_ub = obj.sampleExploration(alpha);
            else
                % EXPLOITATION: Use belief distribution
                eta_ub = obj.sampleExploitation(alpha);
            end
            
            % Record proposed step size
            obj.eta_history(end+1) = eta_ub;
            
            % Apply bounds
            eta_ub = max(obj.min_eta, min(obj.base_eta, eta_ub));
        end
        
        function updateWithResult(obj, tested_etas, tested_phis, exhausted)
            % Update belief based on interpolation results
            % tested_etas: step sizes that were tried
            % tested_phis: corresponding objective values
            % exhausted: whether max_iter was reached
            
            if isempty(tested_etas)
                return;
            end
            
            % Find the accepted step size (last one)
            accepted_eta = tested_etas(end);
            
            % Update exhaustion count
            if exhausted
                obj.exhaustion_count = obj.exhaustion_count + 1;
                % If exhausted, the true optimal is likely smaller
                penalty_factor = 0.7; % Reduce belief mean
                obj.belief_mean = obj.belief_mean * penalty_factor;
            end
            
            % Add to success history with recency weighting
            obj.success_history(end+1) = accepted_eta;
            if length(obj.success_history) > obj.memory_size
                obj.success_history(1) = [];
            end
            
            % Update belief distribution using weighted history
            if length(obj.success_history) >= 3
                weights = obj.memory_decay .^ (length(obj.success_history)-1:-1:0);
                weights = weights / sum(weights);
                
                % Weighted mean and std
                obj.belief_mean = sum(obj.success_history .* weights);
                weighted_var = sum(weights .* (obj.success_history - obj.belief_mean).^2);
                obj.belief_std = sqrt(weighted_var) + 0.1 * obj.belief_mean; % Add minimum std
            end
        end
        
        function eta = sampleExploration(obj, alpha)
            % Sample for exploration (wider distribution)
            
            % Use a mixture model for exploration
            if rand() < 0.5 && ~isempty(obj.success_history)
                % Sample from historical successes
                idx = randi(length(obj.success_history));
                base = obj.success_history(idx);
                noise = randn() * obj.belief_std * 2; % Wider noise
                eta = base + noise;
            else
                % Sample from a wide uniform distribution
                % Bias towards larger values early, smaller values late
                if alpha < 0.3
                    % Early stage: explore larger steps
                    eta = obj.min_eta + rand() * (obj.base_eta - obj.min_eta);
                else
                    % Later stage: explore around current belief
                    center = obj.belief_mean;
                    width = 3 * obj.belief_std;
                    eta = center + (rand() - 0.5) * width;
                end
            end
        end
        
        function eta = sampleExploitation(obj, alpha)
            % Sample for exploitation (focused distribution)
            
            % Use belief distribution with progress-based adjustment
            progress_factor = (1 - alpha * 0.7); % Gradually reduce step size
            
            % Sample from Gaussian around belief mean
            eta = obj.belief_mean * progress_factor + randn() * obj.belief_std * 0.5;
            
            % Apply adaptive bounds based on recent exhaustions
            if obj.exhaustion_count > 3
                % Many exhaustions: bias towards smaller steps
                eta = eta * 0.8;
                obj.exhaustion_count = obj.exhaustion_count - 1; % Decay count
            end
        end
        
        function stats = getStatistics(obj)
            % Return current statistics for monitoring
            stats.belief_mean = obj.belief_mean;
            stats.belief_std = obj.belief_std;
            stats.exploration_prob = obj.exploration_prob;
            stats.exhaustion_count = obj.exhaustion_count;
            stats.recent_successes = obj.success_history(max(1,end-4):end);
        end
    end
end

function value = getfield(s, field, default)
    % Helper function to get field with default value
    if isfield(s, field)
        value = s.(field);
    else
        value = default;
    end
end