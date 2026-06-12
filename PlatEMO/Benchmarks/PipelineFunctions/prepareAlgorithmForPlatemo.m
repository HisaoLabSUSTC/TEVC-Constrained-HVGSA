function algSpec = prepareAlgorithmForPlatemo(algorithmSpec, heuristicPath)
%PREPAREALGORITHMFORPLATEMO Prepare algorithm specification for platemo call
%
%   algSpec = prepareAlgorithmForPlatemo(algorithmSpec, heuristicPath)
%
%   Converts an algorithm specification into the format expected by platemo,
%   appending the heuristic initialization file path for wH algorithms.
%
%   Input:
%     algorithmSpec  - Function handle (@NSGAIIwH) or cell array
%                      ({@ConfigurableNSGA2CHVGSA, config})
%     heuristicPath  - Path to heuristic initial population file
%
%   Output:
%     algSpec - Format suitable for platemo('algorithm', algSpec, ...)
%
%   Examples:
%     % wH algorithm: wraps handle with HID path
%     spec = prepareAlgorithmForPlatemo(@NSGAIIwH, 'init.mat')
%     % Returns: {@NSGAIIwH, 'init.mat'}
%
%     % ConfigurableNSGA2CHVGSA: appends HID to config cell
%     spec = prepareAlgorithmForPlatemo({@ConfigurableNSGA2CHVGSA, config}, 'init.mat')
%     % Returns: {@ConfigurableNSGA2CHVGSA, config, 'init.mat'}
%
%     % Non-wH algorithm: returns unchanged (warning)
%     spec = prepareAlgorithmForPlatemo(@NSGAII, 'init.mat')
%     % Returns: @NSGAII

    if nargin < 2
        heuristicPath = "";
    end

    if ~usesHeuristicInit(algorithmSpec)
        algSpec = algorithmSpec;
        return;
    end

    if isa(algorithmSpec, 'function_handle')
        % Legacy wH handle: {@Handle, HID}
        algSpec = {algorithmSpec, heuristicPath};

    elseif iscell(algorithmSpec)
        handle = algorithmSpec{1};
        className = func2str(handle);

        if strcmp(className, 'ConfigurableNSGA2CHVGSA') || strcmp(className, 'ConfigurableHVGSA') || strcmp(className, 'ConfigurableHVGA')
            % Config-based: {handle, config} -> {handle, config, HID}
            if length(algorithmSpec) >= 2 && isstruct(algorithmSpec{2})
                algSpec = {handle, algorithmSpec{2}, heuristicPath};
            else
                algSpec = {handle, struct(), heuristicPath};
            end
        else
            % Other cell array: append HID
            algSpec = [algorithmSpec, {heuristicPath}];
        end
    else
        error('prepareAlgorithmForPlatemo:InvalidInput', ...
            'algorithmSpec must be a function handle or cell array');
    end
end
