function indices_matrix = rand_combs_from_indices(dims, r)
    % dims: list of positive integers (e.g., [5, 5, 6, 1, 1])
    % r: number of random samples to draw
    
    n = length(dims);
    total_product = prod(dims);
    
    % Verify r is valid
    if r > total_product
        error('r cannot exceed the total product %d', total_product);
    end
    
    % Random sample r integers from 1 to total_product without replacement
    random_linear_indices = randperm(total_product, r);
    
    % Convert each linear index to multi-dimensional indices
    indices_matrix = zeros(r, n);
    
    for i = 1:r
        % Convert 1-based linear index to 0-based for easier computation
        linear_idx = random_linear_indices(i) - 1;
        
        % Convert to multi-dimensional indices using mixed-radix conversion
        for j = n:-1:1
            if j == n
                % Last dimension
                indices_matrix(i, j) = mod(linear_idx, dims(j)) + 1;
                linear_idx = floor(linear_idx / dims(j));
            else
                % Other dimensions
                indices_matrix(i, j) = mod(linear_idx, dims(j)) + 1;
                linear_idx = floor(linear_idx / dims(j));
            end
        end
    end
end