function [v, V, lambda] = GSA(x0_flat,hv_x0_flat,xi_flat,hv_xi_flat)
    %% x0_flat       =       1*d vector
    %% hv_x0_flat    =       1*1 scalar
    %% xi_flat       =       r*d matrix
    %% hv_xi_flat    =       r*1 vector

    % eps = 1e-4;
    d=(hv_xi_flat-hv_x0_flat)./(vecnorm(xi_flat-x0_flat,2,2)); %r*1
    V=((xi_flat-x0_flat)./(vecnorm(xi_flat-x0_flat,2,2)))'; %d*r

    
    % Proof of V^TV is positive definite can be found in 
    % Schutze et al., Gradient subspace approximation: a direct search method for memetic computing

    % Attempt Cholesky decomposition
    % disp("Analyzing matrix V'V");
    % analyzeMatrix(V' * V);
    % pause(10)

    R = chol(V' * V + eye(size(V, 2)), 'upper');
    % lambda = R \ (R' \ (d));
    % disp("Hello")
    % R = modchol_ldlt(V'*V);
    lambda = R \ (R' \ (d));


    
    v=1/(norm(V*lambda))*(V*lambda); %d*1
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
