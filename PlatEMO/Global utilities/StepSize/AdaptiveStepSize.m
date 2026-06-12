function [tested_phis, tested_etas, X1, Xf, trajectory] = AdaptiveStepSize(eta_ub, X0, ref, gradient, d, V, lambda, Problem, CHVmode, max_iter, c1_coeff)
    % Adaptive step size selection using line search with quadratic/cubic interpolation
    % Based on Armijo-Goldstein conditions for hypervolume improvement

    %% Output: 
    %% accepted_etas -- step sizes that were tried.
    %% final_eta -- final eta

    %% Input:
    %% eta_ub -- an upper bound on the step size
    %% x0_flat -| 
    %% y0_flat --- combined into X0. Can use Flatten(x0.decs) to access.
    %% c0_flat -| 
    %% ref -- base reference point
    %% c1_coeff -- coefficient of Wolfe condition
    %% max_iter -- maximum iteration spent on this algorithm?
    %% gradient -- direction to move x0_flat in
    %% d      -|
    %% V      --- Defined in GSA.m
    %% lambda -|
    %% problem -- problem handle so that we could evaluate solutions

    % Default parameters
    if nargin < 10, c1_coeff = 1e-2; end
    if nargin < 11, max_iter = 5; end
    if nargin < 9, CHVmode = "Linear"; end
    
    % Constants
    MIN_ETA = 1e-2;
    
    % Compute initial hypervolume and directional derivative
    phi0 = ComputeHV(X0, ref, CHVmode);
    
    numerator = d' * lambda;
    denom = norm(V * lambda + 1e-6);
    phi_prime0 = numerator/denom;

    trajectory = struct();
    % Early exit if derivative suggests no improvement
    if phi_prime0 <= 0
        warning('Non-ascent direction detected');
        % final_eta = eta;
        tested_etas = [];
        tested_phis = [];
        X1 = X0;
        Xf = X0;
        return;
    end
    
    % Line search loop
    [tested_phis, tested_etas, X1, Xf, trajectory] = performLineSearch(phi0, phi_prime0, eta_ub, X0, ...
            gradient, d, V, lambda, Problem, ref, c1_coeff, max_iter, MIN_ETA, CHVmode);
    
end

function [tested_phis, tested_etas, X1, Xf, trajectory] = performLineSearch(phi0, phi_prime0, eta_ub, X0, ...
                                                  gradient, d, V, lambda, Problem, ref, ...
                                                  c1_coeff, max_iter, MIN_ETA, CHVmode)
    % Main line search with quadratic/cubic interpolation
    
    eta_prev = [];
    phi_prev = [];
    eta = eta_ub;

    % Start tracking eta
    tested_phis = [];
    tested_etas = [];
    X1 = [];
    
    trajectory.pre = cell(1, numel(X0));
    for i=1:numel(X0)
        trajectory.pre{i} = X0(i);
    end
    trajectory.post = cell(1, numel(X0));

    % fprintf("iter: 0. phi(x):% .5f\n", phi0);
    for iter = 1:max_iter
        % Evaluate objective at current step size
        [phi_current, Xtemp] = evaluateStepSize(eta, X0, gradient, Problem, ref, CHVmode);
        X1 = [X1, Xtemp];
        Xf = Xtemp;

        for i=1:numel(X0)
            trajectory.post{i} = [trajectory.post{i}, Xtemp(i)];
        end

        tested_etas = [tested_etas, eta];
        tested_phis = [tested_phis, phi_current];
        % fprintf("iter: %d. eta:% .5f. phi(x):% .5f\n", iter, eta, phi_current);

        % Check Armijo condition
        if checkArmijoCondition(phi_current, phi0, c1_coeff, eta, phi_prime0)
            final_eta = eta;
            return;
        end
        
        % Compute next step size using interpolation
        if iter == 1
            eta_new = quadraticInterpolation(eta, phi0, phi_current, phi_prime0);
        else
            eta_new = cubicInterpolation(eta, eta_prev, phi0, phi_current, ...
                                       phi_prev, phi_prime0);
        end
        

        % Safeguard step size
        eta_new = safeguardStepSize(eta_new, eta, MIN_ETA);
        
        % Update history
        eta_prev = eta;
        phi_prev = phi_current;
        eta = eta_new;
        
        % Check termination
        if eta <= MIN_ETA
            break;
        end
    end
    
    % Return best found
    final_eta = eta;
    tested_etas = [tested_etas, final_eta];
    [final_phi, X1] = evaluateStepSize(eta, X0, gradient, Problem, ref, CHVmode);
    tested_phis = [tested_phis, final_phi];
    X1 = [X1, Xtemp];
    Xf = Xtemp;
    for i=1:numel(X0)
        trajectory.post{i} = [trajectory.post{i}, Xtemp(i)];
    end

    % fprintf("iter: 0. phi(x):% .5f\n", phi0);
    % fprintf("iter: FINAL. phi(x):% .5f\n", phi_end);
    % fprintf("DIFF: % .5f\n", phi_end - phi0);
    % pause(1);
end

function [phi, X1] = evaluateStepSize(eta, X0, gradient, Problem, ref, CHVmode)
    %% A tiny random direction is added to prevent solutions from occupying only the subspace they belong to.
    varepsilon = 1e-5;
    random_dir = rand(size(gradient));
    N = size(X0, 2);

    x0_flat = Flatten(X0.decs);
    x1_flat = x0_flat + gradient .* eta + varepsilon .* random_dir;
    x1_decs = Unflatten(x1_flat, N);
    
    % Evaluate population
    x1_decs = min(Problem.upper, max(Problem.lower, x1_decs));

    X1 = Problem.Evaluation(x1_decs);
    
    % Compute hypervolume
    phi = ComputeHV(X1, ref, CHVmode);
end

function success = checkArmijoCondition(phi_new, phi0, c1, eta, phi_prime0)
    % Check if Armijo condition is satisfied
    success = phi_new >= phi0 + c1 * eta * phi_prime0;
end

function eta_new = quadraticInterpolation(eta, phi0, phi1, phi_prime0)
    % Quadratic interpolation for first iteration
    numerator = -eta^2 * phi_prime0;
    denominator = 2 * (phi1 - phi0 - eta * phi_prime0);

    scale = max(abs(phi0), abs(phi1));
    epsilon = sqrt(eps) * max(scale, 1.0);

    if abs(denominator) < epsilon
        eta_new = eta * 0.5;
    else
        eta_new = numerator / denominator;
    end

    % fprintf("Entered quadratic interpolation. Starting with:\n" + ...
    %     "eta        = % .8f\n" + ...
    %     "abs(denom) = % .8f\n" + ...
    %     "epsilon    = % .8f\n" + ...
    %     "eta_new    = % .8f\n", eta,abs(denominator),epsilon,eta_new);
end

% eta_new = -(eta^2 * phi_prime0) / (2*(HVC_new - phi0 - eta*phi_prime0));

function eta_new = cubicInterpolation(eta, eta_old, phi0, phi_current, phi_old, phi_prime0)
    % Cubic interpolation for subsequent iterations
    
    % Compute function values relative to initial point
    F_old = phi_old - phi0 - phi_prime0 * eta_old;
    F_current = phi_current - phi0 - phi_prime0 * eta;
    
    % Cubic interpolation coefficients
    denom = eta_old^2 * eta^2 * (eta - eta_old);
    
    scale = max([abs(phi0), abs(phi_current), abs(phi_old)]);
    epsilon = sqrt(eps) * max(scale, 1.0);

    if abs(denom) < epsilon
        eta_new = eta / 2;
        return;
    end
    
    a = (eta_old^2 * F_current - eta^2 * F_old) / denom;
    b = (-eta_old^3 * F_current + eta^3 * F_old) / denom;
    
    % Compute discriminant
    discriminant = b^2 - 3*a*phi_prime0;
    
    % Check for valid solution
    if discriminant < 0 || abs(a) < 1e-10
        eta_new = eta / 2;
    else
        eta_new = (-b + sqrt(discriminant)) / (3*a);
    end

    % fprintf("Entered cubic interpolation. Starting with:\n" + ...
    %     "eta        = % .8f\n" + ...
    %     "abs(denom) = % .8f\n" + ...
    %     "epsilon    = % .8f\n" + ...
    %     "discrim    = % .8f\n" + ...
    %     "abs(a)     = % .8f\n" + ...
    %     "eta_new    = % .8f\n", eta,abs(denom),epsilon,discriminant, abs(a), eta_new);
end

function eta_safe = safeguardStepSize(eta_new, eta_current, MIN_ETA)
    % Apply safeguards to computed step size
    
    REDUCTION_FACTOR = 0.5;
    MAX_REDUCTION = 0.1;
    
    % Ensure positive
    if eta_new <= 0
        eta_safe = eta_current * REDUCTION_FACTOR;
        return;
    end
    
    % Ensure not too large
    if eta_new >= eta_current
        eta_safe = eta_current * REDUCTION_FACTOR;
        return;
    end
    
    % Ensure sufficient decrease
    if abs(eta_new - eta_current) < MAX_REDUCTION * eta_current
        eta_safe = eta_current * REDUCTION_FACTOR;
        return;
    end
    
    % Ensure above minimum
    eta_safe = max(eta_new, MIN_ETA);
end

