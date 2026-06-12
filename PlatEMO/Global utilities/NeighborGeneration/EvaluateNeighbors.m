function [Nflat, NFflat, NCflat, Neighbors] = EvaluateNeighbors(Team, N, k, Archive, Problem, C)
    x = Team.decs;
    D = Problem.D;
    
    search_radius = 1e6;
    evaluate_radius = 1e-3;

    Nflat = zeros(k, N * Problem.D);
    NFflat = zeros(k, N * Problem.M);
    NCflat = zeros(k, N * C);

    decs = Archive.decs;
    Neighbors = [];
    for i = 1 : N
        row = x(i, :);
        distance = sum((decs - row).^2, 2);
        distance(distance == 0) = inf;
        indices = find(distance < search_radius);

        has = min(k, numel(indices));
        need = k - has;
        if ~isempty(indices)
            selected = indices(1:has);
        else
            selected = [];
        end

        hO = rand(need, size(row, 2)) - 0.5;
        rowNorms = vecnorm(hO, 2, 2);
        hN = hO ./ rowNorms * evaluate_radius;

        xh = row + hN;
        xh = min(max(xh, Problem.lower), Problem.upper);

        XstartIndex = (i-1) * Problem.D + 1;
        YstartIndex = (i-1) * Problem.M + 1;
        CstartIndex = (i-1) * C + 1;
        XendIndex = i * Problem.D;
        YendIndex = i * Problem.M;
        CendIndex = i * C;

        if need ~= 0
            pop = Problem.Evaluation(xh);
            pop = [pop, Archive(selected)];
            Neighbors = [Neighbors, pop];
        else
            pop = Archive(selected);
            Neighbors = [Neighbors, pop];
        end

        Nflat(:, XstartIndex:XendIndex) = pop.decs;
        NFflat(:, YstartIndex:YendIndex) = pop.objs;
        if C~=0
            NCflat(:, CstartIndex:CendIndex) = pop.cons;
        end
    end
end