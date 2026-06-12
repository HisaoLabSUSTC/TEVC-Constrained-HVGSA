function NormPopDecs = NormalizeDec(PopDecs, Problem)
    
    lower = Problem.lower;
    upper = Problem.upper;
    
    NormPopDecs = (PopDecs - lower)./(upper - lower);
end