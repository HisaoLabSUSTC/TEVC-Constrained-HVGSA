function algSpec = generateHVGSA(varargin)
%GENERATEHVGSA Convenience helper to build a ConfigurableHVGSA spec
%
%   algSpec = generateHVGSA()
%   algSpec = generateHVGSA('eta', 1e-2, 'gradient_method', 'CGSA')
%
%   Returns a cell array {@ConfigurableHVGSA, config} suitable for
%   passing to platemo('algorithm', algSpec, ...).
%
%   Name-value pairs are merged with defaults via parseHVGSAConfig.

    if isempty(varargin) || ~isstruct(varargin{1})
        config = struct();
        for i = 1:2:length(varargin)
            config.(varargin{i}) = varargin{i+1};
        end
        config = parseHVGSAConfig(config);
    else
        config = varargin{1};
        config = parseHVGSAConfig(config);
    end
    algSpec = {@ConfigurableHVGSA, config};
end
