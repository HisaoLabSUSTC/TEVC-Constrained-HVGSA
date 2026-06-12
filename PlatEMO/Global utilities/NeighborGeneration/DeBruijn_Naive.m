function [Res, ResF, ResC] = DeBruijn_Naive(Neighbor, NeighborF, NeighborC, r, k, Problem, N, C)
    % matrix is the k x DN matrix.
    % D is the decision space dimensionality.
    % k is the number of nearest neighbors in the original matrix
    % r is the number of unique new populations to generate.

    %% This method permutes neighbor individuals to create unique population
    %% for the GSA step.
    
    D = Problem.D;
    M = Problem.M;
    
    Res = zeros(r, D*N);
    ResF = zeros(r, M*N);
    ResC = zeros(r, C*N);

    index_sequence = de_bruijn(k, N, r) + 1;

    for unique_index = 2:r+1
        newRow = zeros(1, D*N);
        newRowF = zeros(1, M*N);
        newRowC = zeros(1, C*N);
        indexes = index_sequence(unique_index:unique_index+N-1);

        for team_index = 1:N
            chosen = indexes(team_index);

            idxStart = (team_index-1)*D + 1;
            idxEnd = team_index*D;
            idxStartF = (team_index-1)*M + 1;
            idxEndF = team_index*M;
            idxStartC = (team_index-1)*C + 1;
            idxEndC = team_index*C;

            % disp(chosen);
            

            newRow(idxStart:idxEnd) = Neighbor(chosen, idxStart:idxEnd);
            newRowF(idxStartF:idxEndF) = NeighborF(chosen, idxStartF:idxEndF);
            newRowC(idxStartC:idxEndC) = NeighborC(chosen, idxStartC:idxEndC);

        end
        Res(unique_index-1, :) = newRow;
        ResF(unique_index-1, :) = newRowF;
        ResC(unique_index-1, :) = newRowC;
    end
end

function sequence = de_bruijn(k, N, r)
    % Generate a De Bruijn sequence for given k, N, and desired length r

    % Initialize variables that will be used by the nested function
    a = zeros(1, k * N);
    sequence = [];
    persistent stop_flag;

    if N == 1
        % For N = 1, the sequence is simply the list of symbols
        baseSequence = 0:(k-1);
        % Repeat the sequence to reach the desired length
        repeats = ceil((r + N) / length(baseSequence));
        sequence = repmat(baseSequence, 1, repeats);
        % Trim the sequence to the desired length
        sequence = sequence(1:(r + N));
    else
        % For N > 1, use the recursive function
        stop_flag = false;
        db(1, 1);  % Call the nested function
        clear stop_flag;

        % Trim the sequence to the desired length
        if length(sequence) > r + N
            sequence = sequence(1:(r + N));
        end
    end

    % Nested function must be placed at the end of the main function
    function db(t, p)
        if stop_flag
            return; % Exit if stop flag is set
        end

        if t > N
            if mod(N, p) == 0
                sequence = [sequence, a(2:p+1)];
                if length(sequence) >= r + N
                    stop_flag = true;
                    return;
                end
            end
        else
            a(t+1) = a(t+1-p); 
            db(t+1, p);
            for j = (a(t+1-p)+1):(k-1)
                a(t+1) = j;
                db(t+1, t);
            end
        end
    end
end