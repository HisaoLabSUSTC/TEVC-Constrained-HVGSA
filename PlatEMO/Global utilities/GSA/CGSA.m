function [v, V, lambda, d] = CGSA( x0_flat, ...
                                hv_x0_flat, ...
                                c_x0_flat, ...
                                xi_flat, ...
                                hv_xi_flat, ...
                                c_xi_flat)

    %% x0_flat       =       1*d vector
    %% hv_x0_flat    =       1*1 scalar
    %% c_x0_flat     =       1*p vector
    %% xi_flat       =       r*d matrix
    %% hv_xi_flat    =       r*1 vector
    %% c_xi flat     =       r*p matrix  

    tol = 1e-4;

    %% Dump info
    % disp("c_x0_flat before preprocess");FormatMatrix("% .5f", c_x0_flat);
    % disp("c_xi_flat before preprocess");FormatMatrix("% .5f", c_xi_flat);

    %% Remove inactive constraints:
    %% In raw space, well-satisfied constraints have c < -tol.
    %% In normalized space, all values are >= 0, so we also check
    %% whether the constraint is near-zero at both X0 and all neighbors.
    inactive = (c_x0_flat < -tol) | ...
               (c_x0_flat < tol & all(c_xi_flat < tol, 1));
    active_mask = ~inactive;

    c_x0_flat = c_x0_flat(active_mask);
    c_xi_flat = c_xi_flat(:, active_mask);

    % disp(xi_flat(1,:) - x0_flat);
    % disp(vecnorm(xi_flat(1,:)-x0_flat,2,2));
    % pause(10000);
    tol_eps = 1e-8;
    d=(hv_xi_flat-hv_x0_flat)./(vecnorm(xi_flat-x0_flat,2,2)+tol_eps); %r*1
    V=((xi_flat-x0_flat)./(vecnorm(xi_flat-x0_flat,2,2)+tol_eps))'; %d*r
    if ~isempty(c_x0_flat)
        M=((c_xi_flat-c_x0_flat)./(vecnorm(xi_flat-x0_flat,2,2)+tol_eps))'; %np*r
        h = c_x0_flat';
    else
        M = [];
        h = [];
    end

    r = size(V, 2);
    np = size(h, 1);

    if all(M(:)==0)
        A = V' * V;
        b = d; 
    else
        A = [V' * V, M'; M, zeros(np)];
        b = [d;-h]; 
    end

    lambdamu = pinv(A) * b;
    lambda = lambdamu(1:r, :);

    v=1/(norm(V*lambda))*(V*lambda); %d*1

    %% dump info
    % disp("x0flat");FormatMatrix("% .5f", x0_flat);
    % disp("xiflat");FormatMatrix("% .5f", xi_flat);
    % disp("hv_x0_flat");FormatMatrix("% .5f", hv_x0_flat);
    % disp("hv_xi_flat");FormatMatrix("% .5f", hv_xi_flat);
    % disp("c_x0_flat");FormatMatrix("% .5f", c_x0_flat);
    % disp("c_xi_flat");FormatMatrix("% .5f", c_xi_flat);
    % disp("Xi - X0");FormatMatrix("% .5f", (xi_flat-x0_flat));
    % disp("denom");FormatMatrix("% .5f", (vecnorm(xi_flat-x0_flat,2,2)+eps));
    % disp("V");FormatMatrix("% .5f", V);
    % disp("V'V");FormatMatrix("% .5f", V' * V);
    % disp("M");FormatMatrix("% .5f", M);
    % disp("d");FormatMatrix("% .5f", d);
    % disp("h");FormatMatrix("% .5f", h);
    % disp("A");FormatMatrix("% .5f", A);
    % disp("b");FormatMatrix("% .5f", b);
    % disp("lambdamu");FormatMatrix("% .5f", lambdamu);
    % disp("lambda");FormatMatrix("% .5f", lambda);
end

function pos = analyzeMatrix(A)
    % Display matrix shape
    [m, n] = size(A);
    disp(['Shape of matrix: ', num2str([m, n])]);
    
    % Always compute rank
    matrixRank = rank(A);
    disp(['Rank of matrix: ', num2str(matrixRank)]);

    % --- Compute singular values (works for any shape) ---
    [~, S, ~] = svd(A);
    singularVals = diag(S);

    % Count non-zero singular values (another way of seeing the rank)
    nonZeroSV = sum(singularVals > 1e-14);
    disp(['Number of nonzero singular values: ', num2str(nonZeroSV)]);
    
    % Compute condition number from singular values (if matrix is full rank)
    % (If the smallest singular value is ~0, cond is effectively infinite.)
    if any(singularVals < 1e-14)
        disp('Matrix is (numerically) rank deficient, condition number is very large.');
    else
        condNumberSV = max(singularVals) / min(singularVals);
        disp(['Condition number (SVD-based): ', num2str(condNumberSV)]);
    end
    
    if m == n
        % --- Square matrix-specific computations ---
        disp("Matrix is square.");

        % Eigenvalues
        eigenValues = eig(A);
        
        % Positive definiteness check (all eigenvalues > 0)
        isPositiveDefinite = all(eigenValues > 1e-6);
        if isPositiveDefinite
            disp('The matrix is positive definite.');
        else
            disp('The matrix is NOT positive definite.');
        end
        
        % Determinant
        detA = det(A);
        disp(['Determinant: ', num2str(detA)]);
        
        % Distance to positive definiteness (if negative eigenvalues exist)
        lambdaMin = min(eigenValues);
        if lambdaMin < 0
            disp(['Distance to positive definiteness: ', num2str(abs(lambdaMin))]);
        end
        pos = abs(lambdaMin);
        
        % Check symmetry
        isSymmetric = isequal(A, A');
        disp(['Matrix is symmetric: ', num2str(isSymmetric)]);
        
        % Condition number from eigenvalues (not always well-defined if near singular)
        condNumberEig = max(abs(eigenValues)) / min(abs(eigenValues));
        disp(['Condition number (Eigen-based): ', num2str(condNumberEig)]);
        
    else
        % --- Rectangular matrix-specific note ---
        disp("Matrix is rectangular.");
        disp("Eigenvalues are not directly applicable. Consider A'*A or A*A' if needed.");
    end
end

