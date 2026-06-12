function algSpec = generateHVGA(varargin)
%GENERATEHVGA Convenience helper to build a ConfigurableHVGA spec
%
%   algSpec = generateHVGA()
%   algSpec = generateHVGA('eta', 1e-2, 'delta', 1e-5)
%
%   Returns a cell array {@ConfigurableHVGA, config} suitable for
%   passing to platemo('algorithm', algSpec, ...).
%
%   Name-value pairs are merged with defaults via parseHVGAConfig.

    if isempty(varargin) || ~isstruct(varargin{1})
        config = struct();
        for i = 1:2:length(varargin)
            config.(varargin{i}) = varargin{i+1};
        end
        config = parseHVGAConfig(config);
    else
        config = varargin{1};
        config = parseHVGAConfig(config);
    end
    algSpec = {@ConfigurableHVGA, config};
end
