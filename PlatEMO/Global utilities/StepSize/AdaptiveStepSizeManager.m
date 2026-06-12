classdef AdaptiveStepSizeManager < handle
    % Manager class for adaptive step size upper bounds
    % Tracks history of ACTUAL USED step sizes to propose new upper bounds
    
    properties
        method          % 'exponential_avg', 'windowed_avg', 'percentile', 'discounted', 'fixed'
        base_eta        % Initial base learning rate
        
        % History tracking
        eta_history     % History of ACTUAL USED eta values
        window_size = 10 % For windowed average
        
        % Exponential average parameters
        exp_alpha = 0.7  % Weight for new values (higher = more responsive)
        exp_avg         % Running exponential average
        
        % Percentile parameters
        percentile = 75  % Use 75th percentile of recent etas
        
        % Discounted parameters
        discount_rate = 0.9
        
        % Aggressive return parameters
        return_gamma = 0.9    % Discount factor for return calculation
        return_lookahead = 5  % How many future steps to consider

        % Safety parameters
        min_eta = 1e-8
        max_eta = 100
        growth_factor = 100  % Max growth between iterations
        shrink_factor = 1e-8  % Min shrink between iterations

        % Convergence parameters
        iteration_count = 0
        convergence_patience = 100  % Start reducing after this many iterations
        convergence_rate = 0.99     % Decay factor after patience exceeded
    end
    
    methods
        function obj = AdaptiveStepSizeManager(method, base_eta)
            % Constructor
            % method: 'exponential_avg', 'windowed_avg', 'percentile', 'discounted', 'fixed'
            % base_eta: initial base learning rate
            
            obj.method = lower(method);
            obj.base_eta = base_eta;
            obj.eta_history = [];
            obj.exp_avg = base_eta;
        end
        
        function base_eta = proposeBaseEta(obj)
            % Propose a base eta (upper bound) for line search
            % Based on history of actual used etas
            
            if isempty(obj.eta_history)
                % First iteration, return initial base eta
                base_eta = obj.base_eta;
                return;
            end
            
            switch obj.method
                case 'exponential_avg'
                    base_eta = obj.exponentialAverageStep();
                    
                case 'windowed_avg'
                    base_eta = obj.windowedAverageStep();
                    
                case 'percentile'
                    base_eta = obj.percentileStep();
                    
                case 'discounted'
                    base_eta = obj.discountedStep();
                    
                case 'aggressive_return'
                    base_eta = obj.aggressiveReturnStep();

                case 'fixed'
                    base_eta = obj.eta_history(end);
                    
                otherwise
                    error('Unknown method: %s', obj.method);
            end

            if ismember(obj.method, {'aggressive_return', 'adaptive_aggressive', 'cyclic_aggressive'})
                base_eta = obj.applyConvergenceDecay(base_eta);
            end

            % Apply safety bounds
            base_eta = obj.applySafetyBounds(base_eta);
        end
        
        function updateWithUsedEta(obj, used_eta)
            % Update the manager with the ACTUAL eta used by line search
            
            obj.eta_history = [obj.eta_history, used_eta];
            
            % Update exponential average if using that method
            if strcmp(obj.method, 'exponential_avg')
                obj.exp_avg = obj.exp_alpha * used_eta + (1 - obj.exp_alpha) * obj.exp_avg;
            end
        end
        
        function eta = exponentialAverageStep(obj)
            % Exponential moving average of actual used etas
            % Gives more weight to recent values
            
            % Use a multiplier to set upper bound above average
            multiplier = 1.5;  % Upper bound is 1.5x the average
            eta = obj.exp_avg * multiplier;
        end
        
        function eta = windowedAverageStep(obj)
            % Average of last N actual used etas
            
            recent_etas = obj.eta_history(max(1, end-obj.window_size+1):end);
            avg_eta = mean(recent_etas);
            
            % Set upper bound based on average and variance
            std_eta = std(recent_etas);
            eta = avg_eta + std_eta;  % One std above mean
        end
        
        function eta = percentileStep(obj)
            % Use percentile of recent etas as upper bound
            
            recent_etas = obj.eta_history(max(1, end-obj.window_size+1):end);
            eta = prctile(recent_etas, obj.percentile);
            
            % Add small margin above percentile
            eta = eta * 1.2;
        end
        
        function eta = discountedStep(obj)
            % Exponentially discounted based on last used eta
            
            last_eta = obj.eta_history(end);
            eta = last_eta / obj.discount_rate;  % Divide to get upper bound
        end
        
        function eta = aggressiveReturnStep(obj)
            % RL-inspired return calculation: η_t = γ + γη_{t-1} + γ²η_{t-2} + ...
            % This naturally pushes eta above base_eta
            
            n = length(obj.eta_history);
            lookback = min(n, obj.return_lookahead);
            
            % Compute discounted return
            eta = obj.return_gamma;  % Base term
            for i = 1:lookback
                idx = n - i + 1;
                eta = eta + (obj.return_gamma^i) * obj.eta_history(idx);
            end
            
            % Add exploration bonus early in optimization
            if obj.iteration_count < 50
                exploration_bonus = 0.5 * obj.base_eta * (1 - obj.iteration_count/50);
                eta = eta + exploration_bonus;
            end
        end

        function eta_safe = applySafetyBounds(obj, eta)
            % Apply safety constraints to proposed eta
            
            % Absolute bounds
            eta_safe = max(obj.min_eta, min(obj.max_eta, eta));
            
            % Limit growth/shrink rate if we have history
            if ~isempty(obj.eta_history)
                last_used = obj.eta_history(end);
                max_allowed = last_used * obj.growth_factor;
                min_allowed = last_used * obj.shrink_factor;
                eta_safe = max(min_allowed, min(max_allowed, eta_safe));
            end

        end
        
        function eta_decay = applyConvergenceDecay(obj, eta)
            % Apply decay to ensure convergence for aggressive methods
            
            if obj.iteration_count <= obj.convergence_patience
                % No decay during initial exploration phase
                eta_decay = eta;
            else
                % Exponential decay after patience exceeded
                decay_iterations = obj.iteration_count - obj.convergence_patience;
                decay_factor = obj.convergence_rate ^ decay_iterations;
                
                % Blend between aggressive eta and conservative estimate
                conservative_eta = mean(obj.eta_history(max(1, end-4):end));
                eta_decay = decay_factor * eta + (1 - decay_factor) * conservative_eta;
            end
        end

        function stats = getStatistics(obj)
            % Get statistics about eta history
            
            if isempty(obj.eta_history)
                stats = struct('mean', NaN, 'std', NaN, 'min', NaN, 'max', NaN);
                return;
            end
            
            stats.mean = mean(obj.eta_history);
            stats.std = std(obj.eta_history);
            stats.min = min(obj.eta_history);
            stats.max = max(obj.eta_history);
            stats.length = length(obj.eta_history);
            
            if length(obj.eta_history) > 1
                stats.trend = obj.eta_history(end) / obj.eta_history(1);
            else
                stats.trend = 1;
            end
        end
    end
end