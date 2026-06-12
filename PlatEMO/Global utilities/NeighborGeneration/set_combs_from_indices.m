function indices_matrix = set_combs_from_indices(dims, D)
    % dims: list of positive integers (e.g., [5, 5, 6, 1, 1])
    % D: decision variable dimensions
    %
    % Generates one-at-a-time neighbor configurations: each row has all ones
    % except one column that varies from 2..dims(i). This gives the finite
    % difference sampling pattern for gradient approximation.

    n = length(dims);
    dims = min(dims, D + 1);
    total_rows = sum(dims - 1);  % exact: each column contributes (dims(i)-1) rows

    indices_matrix = zeros(total_rows, n);

    row = 1;
    for i = 1:n
        for j = 2:dims(i)       % skip j=1 (the all-ones row)
            indices_matrix(row, :) = ones(1, n);
            indices_matrix(row, i) = j;
            row = row + 1;
        end
    end
end
