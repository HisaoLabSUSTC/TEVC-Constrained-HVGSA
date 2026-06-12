function Neighbors = GenerateArtificialNeighbors(X0, Problem, method, delta)

    if nargin < 3
        method = "radial";
    end
    
    if nargin < 4
        delta = 1e-6;
    end

    N = numel(X0);
    D = Problem.D;
    Neighbors = cell(1, N*D);
    ranges = Problem.upper - Problem.lower;
    base_decs = X0.decs;

    if strcmp(method, "dimensional")
        delta_abs = delta * ranges;

        for i=1:N
            for j=1:D
                idx = (i-1)*D+j;
                all_pert_decs(idx, :) = base_decs(i, :);
                all_pert_decs(idx, j) = all_pert_decs(idx, j) + delta_abs(j);
            end
        end

        sampledSolutions = Problem.Evaluation(all_pert_decs);
        for i=1:N
            tempPop = X0;
            for j=1:D
                idx = (i-1)*D+j;
                tempPop(i) = sampledSolutions(idx);
                Neighbors{idx} = tempPop;
            end
        end
    elseif strcmp(method, "radial")
        X0_decs = X0.decs;
        Flat_X0_decs = Flatten(X0_decs);

        radius = 5e-1;
        % radius = 5e-3; % Example CBOP
        
        counter = 1;
        for i=1:N
            Flat_Xi_decs = Flat_X0_decs;
            start_idx = (i-1)*D+1;
            end_idx = start_idx+D-1;

            for j=1:D
                dir = randn(D,1);
                dir = dir/norm(dir);
                rho = radius * rand()^(1/D);
                delta = rho*dir';
    
                Flat_Xi_decs(start_idx:end_idx) = Flat_Xi_decs(start_idx:end_idx) + delta;
                Xi_decs = Unflatten(Flat_Xi_decs, N);
                Xi = Problem.Evaluation(Xi_decs);
                Neighbors{counter} = Xi;
                counter = counter + 1;
            end
        end

    else
        warning("Not implemented.");
    end

end

