function [Neighbors, Norm_Neighbors] = GenerateNormedArtificialNeighbors(X0, Problem, NormStruct, method)

    if nargin < 3
        method = "radial";
    end

    N = numel(X0);
    D = Problem.D;
    Neighbors = cell(1, N*D);
    Norm_Neighbors = cell(1, N*D);

    if strcmp(method, "dimensional")
        X0_decs = X0.decs;
        Flat_X0_decs = Flatten(X0_decs);

        coeff = 1;
        offset = rand(1, N*D) * coeff;
        for i=1:N*D
            Flat_Xi_decs = Flat_X0_decs;
            Flat_Xi_decs(i) = Flat_Xi_decs(i) + offset(i);
            Xi_decs = Unflatten(Flat_Xi_decs, N);
            Xi = Problem.Evaluation(Xi_decs);
            [Norm_Xi_objs, Norm_Xi_cons, ~] = NormReference( ...
                Xi.objs, Xi.cons, NormStruct);
            Norm_Xi = SOLUTION(Xi.decs, Norm_Xi_objs, Norm_Xi_cons);

            Neighbors{i} = Xi;
            Norm_Neighbors{i} = Norm_Xi;
        end
    elseif strcmp(method, "radial")
        X0_decs = X0.decs;
        Flat_X0_decs = Flatten(X0_decs);

        radius = 5e-1;
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

                [Norm_Xi_objs, Norm_Xi_cons, ~] = NormReference( ...
                Xi.objs, Xi.cons, NormStruct);
                Norm_Xi = SOLUTION(Xi.decs, Norm_Xi_objs, Norm_Xi_cons);

                Neighbors{counter} = Xi;
                Norm_Neighbors{counter} = Norm_Xi;
                counter = counter + 1;
            end
        end

    else
        warning("Not implemented.");
    end

end

