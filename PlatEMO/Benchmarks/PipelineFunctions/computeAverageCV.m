function avgCV = computeAverageCV(popCon)
%COMPUTEAVERAGECV Compute average total constraint violation of a population.
%
%   avgCV = computeAverageCV(popCon)
%
%   Computes the mean of total constraint violation across all individuals:
%     CV_i = sum(max(0, g_j(x_i)))  for each individual i
%     avgCV = mean(CV_i)
%
%   Input:
%     popCon - N x p matrix of constraint values (positive = violation)
%
%   Output:
%     avgCV - Average total constraint violation (>= 0)

    if isempty(popCon)
        avgCV = 0;
        return;
    end

    totalCV = sum(max(0, popCon), 2);
    avgCV = mean(totalCV);
end
