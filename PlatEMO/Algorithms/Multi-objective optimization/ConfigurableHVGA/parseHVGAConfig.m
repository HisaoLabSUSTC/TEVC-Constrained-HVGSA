function config = parseHVGAConfig(input)
%PARSEHVGACONFIG Merge user-provided config with defaults for standalone HVGA
%
%   config = parseHVGAConfig(struct('eta', 1e-2))
%
%   Default config:
%     eta=1e-3, delta=1e-6, ref=[] (auto-compute from population),
%     name_override=''

    config = struct( ...
        'eta',               1e-3, ...
        'delta',             1e-6, ...
        'ref',               [], ...
        'name_override',     '' ...
    );

    if nargin == 0 || isempty(input)
        return;
    end

    if ~isstruct(input)
        error('parseHVGAConfig:badInput', 'Input must be a struct');
    end

    fields = fieldnames(input);
    for i = 1:length(fields)
        config.(fields{i}) = input.(fields{i});
    end
end
