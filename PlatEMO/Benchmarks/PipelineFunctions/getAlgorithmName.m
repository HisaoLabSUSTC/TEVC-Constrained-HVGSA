function algName = getAlgorithmName(algorithmSpec)
%GETALGORITHMNAME Extract algorithm name from various specification formats
%
%   algName = getAlgorithmName(algorithmSpec)
%
%   Handles three types of algorithm specifications:
%     1. Function handle: @NSGAII -> "NSGAII"
%     2. Cell array with config: {@ConfigurableNSGA2CHVGSA, config} -> name from config
%     3. String/char: 'NSGAII' -> "NSGAII"
%
%   Returns:
%     algName - Internal name for file paths (e.g., "NSGA2CHVGSA", "CMOEACD")
%
%   Examples:
%     name = getAlgorithmName(@NSGAII)
%     % name = "NSGAII"
%
%     name = getAlgorithmName(generateCHVGSA('use_normalization', false))
%     % name = "NSGA2CHVGSAWN"

    if isa(algorithmSpec, 'function_handle')
        algName = func2str(algorithmSpec);

    elseif iscell(algorithmSpec)
        handle = algorithmSpec{1};
        className = func2str(handle);

        if strcmp(className, 'ConfigurableNSGA2CHVGSA')
            if length(algorithmSpec) >= 2 && isstruct(algorithmSpec{2})
                config = algorithmSpec{2};
            else
                config = struct();
            end
            config = parseCHVGSAConfig(config);
            algName = config2name_CHVGSA(config);
        else
            algName = className;
        end

    elseif ischar(algorithmSpec) || isstring(algorithmSpec)
        algName = char(algorithmSpec);

    else
        error('getAlgorithmName:InvalidInput', ...
            'algorithmSpec must be a function handle, cell array, or string');
    end
end
