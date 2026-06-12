function [C, gn, hn] = ExtractConstraintInformation(Problem)
    %% You have to manually set the Problem.parameter.gn/hn in the problems
    %% by checking their problem definitions.
    if isfield(Problem.parameter, 'gn')
        gn = Problem.parameter.gn;
        hn = Problem.parameter.hn;
    else
        gn = 0;
        hn = 0;
    end
    C = gn+hn;
end

