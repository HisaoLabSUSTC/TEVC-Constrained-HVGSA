function algSpec = generateCHVGSA(varargin)
%GENERATECHVGSA Convenience helper to build a ConfigurableNSGA2CHVGSA spec
%
%   algSpec = generateCHVGSA('use_normalization', false)
%   algSpec = generateCHVGSA('use_normalization', false, 'eta_mode', 'constant_one')
%
%   Returns a cell array {@ConfigurableNSGA2CHVGSA, config} suitable for
%   passing to platemo('algorithm', algSpec, ...).
%
%   Name-value pairs are merged with defaults via parseCHVGSAConfig.

    if isempty(varargin) || ~isstruct(varargin{1})
        config = struct();
        for i = 1:2:length(varargin)
            config.(varargin{i}) = varargin{i+1};
        end
        config = parseCHVGSAConfig(config);
    else
        config = varargin{1};
        config = parseCHVGSAConfig(config);
    end
    algSpec = {@ConfigurableNSGA2CHVGSA, config};
end
