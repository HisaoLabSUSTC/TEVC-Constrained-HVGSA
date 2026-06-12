function [PopCon, C, gn, hn] = ImposeBoundary(Population, Problem)
    %% Impose boundary constraints onto the population by concatenating 
    %% them to Population.cons

    [C, gn, hn] = ExtractConstraintInformation(Problem);

    %% Update C and gn
    count_bound = numel(Problem.lower) + numel(Problem.upper);
    C = C + count_bound;
    gn = gn + count_bound;

    %% Update Population.cons
    % Old gn: gn - count_bound;
    PopCon = Population.cons;
    
    %% Obtain BoundCon using matrix operations
    Scale = Problem.upper - Problem.lower;
    Scale_const = 1e-3;
    LowerBoundCon = Problem.lower + Scale * Scale_const - Population.decs;
    UpperBoundCon = Population.decs + Scale * Scale_const - Problem.upper;

    BoundCon = [LowerBoundCon, UpperBoundCon];

    if (C - count_bound <= 0)
        %% Construct
        PopCon = BoundCon;
    else
        %% Concatenate
        PopCon = [BoundCon, PopCon];
    end
end

