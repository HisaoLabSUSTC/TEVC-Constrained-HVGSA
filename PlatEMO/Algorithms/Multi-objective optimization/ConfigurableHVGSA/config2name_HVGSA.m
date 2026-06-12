function name = config2name_HVGSA(config)
%CONFIG2NAME_HVGSA Generate variant name from standalone HVGSA config struct
%
%   name = config2name_HVGSA(config)
%
%   If config.name_override is set, returns that directly.
%   Otherwise auto-generates: 'HVGSA' + suffix tokens.
%
%   Suffix tokens (appended when non-default):
%     SN          = neighbor_mode = 'select'
%     HY          = neighbor_mode = 'hybrid'
%     A{v}        = non-zero a (hybrid mode)
%     Q{v}        = non-default Qsize (not 50)
%     SR{mode}    = non-default sr_mode (not 'mean')
%     K{v}        = non-default k_min (not 1)
%     FR          = fixed reference point (ref is non-empty)
%     FN          = full normalization / CGSA (gradient_method='CGSA')
%     E{v}        = non-default eta (eta ~= 1e-3)

    % Override takes precedence
    if isfield(config, 'name_override') && ~isempty(config.name_override)
        name = config.name_override;
        return;
    end

    base = 'HVGSA';
    suffix = '';

    % Neighbor mode
    if isfield(config, 'neighbor_mode')
        switch config.neighbor_mode
            case 'archive'
                % default, no suffix
            case 'select'
                suffix = [suffix 'SN'];
            case 'hybrid'
                suffix = [suffix 'HY'];
        end
    end

    % a (hybrid neighbor count)
    if isfield(config, 'a') && config.a ~= 0
        suffix = [suffix 'A' num2str(config.a)];
    end

    % Qsize
    if isfield(config, 'Qsize') && config.Qsize ~= 50
        suffix = [suffix 'Q' num2str(config.Qsize)];
    end

    % sr_mode
    if isfield(config, 'sr_mode') && ~strcmp(config.sr_mode, 'mean')
        suffix = [suffix 'SR' config.sr_mode];
    end

    % k_min
    if isfield(config, 'k_min') && config.k_min ~= 1
        suffix = [suffix 'K' num2str(config.k_min)];
    end

    % Fixed reference point
    if ~isempty(config.ref)
        suffix = [suffix 'FR'];
    end

    % Gradient method (non-default)
    if strcmp(config.gradient_method, 'CGSA')
        suffix = [suffix 'FN'];
    end

    % Non-default eta
    if config.eta ~= 1e-3
        suffix = [suffix 'E' num2str(config.eta)];
    end

    name = [base suffix];
end
