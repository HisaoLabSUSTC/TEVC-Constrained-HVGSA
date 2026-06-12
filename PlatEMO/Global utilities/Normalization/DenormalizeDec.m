function PopDecs = DenormalizeDec(NormPopDecs, Problem)
    
    lower = Problem.lower;
    upper = Problem.upper;
    
    PopDecs = NormPopDecs .* (upper - lower) + lower;
end