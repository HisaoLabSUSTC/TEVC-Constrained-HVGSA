function [tested_phis, tested_etas, Xs, trajectory] = ...
        SolutionWiseNormAdaptiveStepSize(eta_ub, X0, ref, gradient, d, V, ...
        lambda, Problem, NormStruct, max_iter, c1_coeff)
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

    %% Xs needs to return Unnormalized solutions!

    % Default parameters
    if nargin < 10, max_iter = 5; end
    if nargin < 11, c1_coeff = 1e-2; end
    % if nargin < 9, CHVmode = "Linear"; end
    CHVmode = "Feasible";
    
    % Constants
    MIN_ETA = 1e-6;
    
    % Compute initial hypervolume and directional derivative
    [Norm_X0_objs, Norm_X0_cons, ~] = NormReference(X0.objs, X0.cons, NormStruct);
    Norm_X0 = SOLUTION(X0.decs, Norm_X0_objs, Norm_X0_cons);
    phi0 = ComputeHV(Norm_X0, ref, CHVmode);
   
    %% Update all outputs.
    [phi_min, X1] = evaluateStepSize(MIN_ETA, X0, gradient, Problem, ref, CHVmode, NormStruct);
    phi_prime0 = (phi_min-phi0)/MIN_ETA;
    cv_win = checkCVCondition(X0, X1, NormStruct);

    trajectory = struct();
    % Early exit if derivative suggests no improvement
    if phi_prime0 <= 0
        if ~cv_win
            warning('Non-ascent direction detected');
            % final_eta = eta;
            tested_etas = [];
            tested_phis = [];
            Xs = X0;
            return;
        end
    end
    
    % Line search loop
    [tested_phis, tested_etas, Xs, trajectory] = performLineSearch(phi0, phi_prime0, eta_ub, X0, ...
            gradient, Problem, ref, c1_coeff, max_iter, MIN_ETA, CHVmode, NormStruct);
    
end

function [tested_phis, tested_etas, Xs, trajectory] = performLineSearch(phi0, phi_prime0, eta_ub, X0, ...
                                                  gradient, Problem, ref, c1_coeff, max_iter, ...
                                                  MIN_ETA, CHVmode, NormStruct)
    % Main line search with quadratic/cubic interpolation
    eta_prev = [];
    phi_prev = [];
    eta = eta_ub;

    % Start tracking eta
    tested_phis = [];
    tested_etas = [];
    Xs = [];
    trajectory.pre = cell(1, numel(X0));
    for i=1:numel(X0)
        trajectory.pre{i} = X0(i);
    end
    trajectory.post = cell(1, numel(X0));

    %% Main loop of interpolation
    for iter = 1:max_iter
        %% Evaluate phi at current step size
        [phi_current, X1] = evaluateStepSize(eta, X0, gradient, Problem, ref, CHVmode, NormStruct);
        
        Xs = [Xs, X1];
        tested_etas = [tested_etas, eta];
        tested_phis = [tested_phis, phi_current];
        for i=1:numel(X0)
            trajectory.post{i} = [trajectory.post{i}, X1(i)];
        end
        

        %% Check Armijo condition
        CV_success = checkCVCondition(X0, X1, NormStruct);
        HV_success = checkArmijoCondition(phi_current, phi0, c1_coeff, eta, phi_prime0);

        if CV_success || HV_success
            % pause(0.01);
            return;
        end
        
        %% If NO feasible solutions
        if phi0 == 0 && phi_prime0 == 0
            eta_new = eta/2;
            % disp("NO FEASIBLE")
        else
            %% Compute next step size using interpolation
            if iter == 1
                eta_new = quadraticInterpolation(eta, phi0, phi_current, phi_prime0);
            else
                eta_new = cubicInterpolation(eta, eta_prev, phi0, phi_current, ...
                                           phi_prev, phi_prime0);
            end
        end
        
        %% Safeguard step size (Ensure not too big, not too small, step not too big)
        eta_new = safeguardStepSize(eta_new, eta, MIN_ETA);
        
        %% Update history
        eta_prev = eta;
        phi_prev = phi_current;
        eta = eta_new;
        
        %% Check termination
        if eta <= MIN_ETA
            break;
        end
    end
    
    % Return best found
    final_eta = eta;
    [final_phi, X1] = evaluateStepSize(final_eta, X0, gradient, Problem, ref, CHVmode, NormStruct);
    Xs = [Xs, X1];
    tested_etas = [tested_etas, final_eta];
    tested_phis = [tested_phis, final_phi];
    for i=1:numel(X0)
        trajectory.post{i} = [trajectory.post{i}, X1(i)];
    end

    % pause(0.01);
    % fprintf("iter: 0. phi(x):% .5f\n", phi0);
    % fprintf("iter: FINAL. phi(x):% .5f\n", phi_end);
    % fprintf("DIFF: % .5f\n", phi_end - phi0);
    % pause(1);
end

function [phi, X1] = evaluateStepSize(eta, X0, gradient, Problem, ref, CHVmode, NormStruct)
    %% A tiny random direction is added to prevent solutions from occupying only the subspace they belong to.
    varepsilon = 1e-8;
    % varepsilon = 0;
    random_dir = rand(size(gradient));
    N = size(X0, 2);

    x0_flat = Flatten(X0.decs);
    x1_flat = x0_flat + gradient .* eta + varepsilon .* random_dir;
    x1_decs = Unflatten(x1_flat, N);
    
    % Evaluate population
    x1_decs = min(Problem.upper, max(Problem.lower, x1_decs));
    X1 = Problem.Evaluation(x1_decs);

    [Norm_X1_objs, Norm_X1_cons, ~] = NormReference(X1.objs, X1.cons, NormStruct);
    Norm_X1 = SOLUTION(X1.decs, Norm_X1_objs, Norm_X1_cons);
    
    % Compute hypervolume
    phi = ComputeHV(Norm_X1, ref, CHVmode);
end

function success = checkArmijoCondition(phi_new, phi0, c1, eta, phi_prime0)
    % Check if Armijo condition is satisfied
    success = phi_new > phi0 + c1 * eta * phi_prime0;
end

function success = checkCVCondition(X0, X1, NormStruct)
    % Check if average CV is reduced

    %% TODO: test min and max
    [~, avg_CV_X0,~] = TotalCV(X0.cons);
    [~, avg_CV_X1,~] = TotalCV(X1.cons);
    
    % fprintf("CV(X0): % .4f. CV(X1): % .4f\n", avg_CV_X0, avg_CV_X1);
    % pause(0.025);

    success = avg_CV_X1 < avg_CV_X0;
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
    MAX_REDUCTION = 0.25;
    
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

