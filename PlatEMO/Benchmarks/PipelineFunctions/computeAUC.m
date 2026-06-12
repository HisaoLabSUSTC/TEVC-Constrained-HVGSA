function auc = computeAUC(metricValues, feValues)
%COMPUTEAUC Compute area under the curve using trapezoidal integration.
%
%   auc = computeAUC(metricValues, feValues)
%
%   Input:
%     metricValues - 1 x G vector of metric values at each snapshot
%     feValues     - 1 x G vector of function evaluation counts
%
%   Output:
%     auc - Area under the curve (integral of metric over FE)

    if isempty(metricValues)
        auc = 0;
        return;
    end

    if numel(metricValues) < 2
        auc = metricValues(1);
        return;
    end

    auc = trapz(feValues, metricValues);
end
