function tf = usesHeuristicInit(algorithmSpec)
%USESHEURISTICINIT Check if an algorithm uses heuristic initialization
%
%   tf = usesHeuristicInit(algorithmSpec)
%
%   Returns true if the algorithm name ends with 'wH' or is a
%   ConfigurableNSGA2CHVGSA variant (which always accepts HID).

    if isa(algorithmSpec, 'function_handle')
        name = func2str(algorithmSpec);
    elseif iscell(algorithmSpec)
        name = func2str(algorithmSpec{1});
    elseif ischar(algorithmSpec) || isstring(algorithmSpec)
        name = char(algorithmSpec);
    else
        tf = false;
        return;
    end

    tf = endsWith(name, 'wH') ...
        || strcmp(name, 'ConfigurableNSGA2CHVGSA') ...
        || strcmp(name, 'ConfigurableHVGSA') ...
        || strcmp(name, 'ConfigurableHVGA') ...
        || strcmp(name, 'ICMACHVGSA') ...
        || strcmp(name, 'CMOEACDCHVGSA');
end
