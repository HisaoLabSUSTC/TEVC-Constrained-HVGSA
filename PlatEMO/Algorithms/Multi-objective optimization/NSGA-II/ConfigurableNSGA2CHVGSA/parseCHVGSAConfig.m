function config = parseCHVGSAConfig(input)
%PARSECHVGSACONFIG Merge user-provided config with defaults for C-HVGSA
%
%   config = parseCHVGSAConfig(struct('use_normalization', 'obj'))
%
%   Default config matches Ablation-VI base (NSGA2CHVGSA):
%     eta_mode='adaptive', use_normalization='both', Qsize=50,
%     use_expanded_front=true, use_interpolation=true,
%     gradient_method='CGSA_n', U_mode='random', U_range=[6 10],
%     sr_mode='mean', k_min=1, refC='adaptive', norm_eps=1e-6
%
%   use_normalization: 'both' | 'obj' | 'off'
%     'both' — normalize objectives and constraints (default)
%     'obj'  — normalize objectives only
%     'off'  — no normalization
%     true/false are accepted for backward compatibility
%
%   refC: 'adaptive' | numeric
%     'adaptive' — use 1+1/H as reference constant (default)
%     numeric    — use the given value directly (e.g., 1.05, 1.1, 1.2)
%
%   Qsize: non-negative integer
%     0  — archive disabled; History is the current Mixture (no archive)
%     >0 — archive enabled with the given queue capacity (default 50)

    config = struct( ...
        'eta_mode',           'adaptive', ...
        'use_normalization',  'off',  ...
        'use_expanded_front', true,  ...
        'use_interpolation',  true,  ...
        'gradient_method',    'CGSA_n', ...
        'U_mode',             'random', ...
        'U_range',            [6, 10], ...
        'U_value',            8, ...
        'sr_mode',            'mean', ...
        'k_min',              1, ...
        'refC',               'adaptive', ...
        'ref_source',         'population', ...
        'Qsize',              50, ...
        'norm_eps',           1e-6, ...
        'name_override',      '' ...
    );

    if nargin == 0 || isempty(input)
        return;
    end

    if ~isstruct(input)
        error('parseCHVGSAConfig:badInput', 'Input must be a struct');
    end

    fields = fieldnames(input);
    for i = 1:length(fields)
        if strcmp(fields{i}, 'use_archive')
            % Backward compatibility: map use_archive -> Qsize
            if ~input.use_archive
                config.Qsize = 0;
            end
            % use_archive=true falls back to whatever Qsize is set to
            continue;
        end
        config.(fields{i}) = input.(fields{i});
    end

    %% Backward compatibility: convert boolean use_normalization
    if islogical(config.use_normalization)
        if config.use_normalization
            config.use_normalization = 'both';
        else
            config.use_normalization = 'off';
        end
    end

    %% Validate Qsize
    if ~isnumeric(config.Qsize) || config.Qsize < 0 || config.Qsize ~= floor(config.Qsize)
        error('parseCHVGSAConfig:badQsize', ...
            'Qsize must be a non-negative integer (0 disables archive)');
    end
end
