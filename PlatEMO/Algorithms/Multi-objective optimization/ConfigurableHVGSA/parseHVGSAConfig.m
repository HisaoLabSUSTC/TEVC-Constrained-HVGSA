function config = parseHVGSAConfig(input)
%PARSEHVGSACONFIG Merge user-provided config with defaults for standalone HVGSA
%
%   config = parseHVGSAConfig(struct('eta', 1e-2))
%
%   Default config:
%     eta=1e-3, ref=[] (auto-compute from population),
%     gradient_method='CGSA_n', name_override='',
%     neighbor_mode='archive', Qsize=50, a=0,
%     sr_mode='mean', k_min=1
%
%   neighbor_mode: 'archive' | 'select' | 'hybrid'
%     'archive' — each past population in the archive is one neighbor
%                 in the mu*n concatenated decision space.
%     'select'  — SelectNeighbors against the archive, no truncation.
%     'hybrid'  — 'select' plus up to 'a' artificial neighbors generated
%                 near the current team each generation.
%
%   Qsize: archive capacity (default 50, matching ConfigurableNSGA2CHVGSA).
%   a: number of artificial neighbors per iteration in 'hybrid' mode
%      (0..mu*n; a=mu*n approximates the true HV gradient).

    config = struct( ...
        'eta',               1e-3, ...
        'ref',               [], ...
        'gradient_method',   'CGSA_n', ...
        'name_override',     '', ...
        'neighbor_mode',     'archive', ...
        'Qsize',             50, ...
        'a',                 0, ...
        'sr_mode',           'mean', ...
        'k_min',             1, ...
        'delta',             1e-6 ...
    );

    if nargin == 0 || isempty(input)
        return;
    end

    if ~isstruct(input)
        error('parseHVGSAConfig:badInput', 'Input must be a struct');
    end

    fields = fieldnames(input);
    for i = 1:length(fields)
        config.(fields{i}) = input.(fields{i});
    end
end
