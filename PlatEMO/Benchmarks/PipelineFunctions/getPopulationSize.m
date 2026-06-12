function N = getPopulationSize(M)
%GETPOPULATIONSIZE Return population size for a given number of objectives.
%
%   N = getPopulationSize(M)
%
%   Centralized lookup table mapping the number of objectives M to the
%   appropriate population size N. Used by the benchmark pipeline to set
%   per-problem population sizes.
%
%   Input:
%     M - Number of objectives (scalar)
%
%   Output:
%     N - Population size (scalar)

    MtoN = [2,120; 3,120; 4,120; 5,210; 6,252; 7,294; 8,238; 9,210; 10,275];
    idx = MtoN(:,1) == M;
    if any(idx)
        N = MtoN(idx, 2);
    else
        warning('getPopulationSize:UnknownM', ...
            'No population size defined for M=%d, using default N=120.', M);
        N = 120;
    end
end
