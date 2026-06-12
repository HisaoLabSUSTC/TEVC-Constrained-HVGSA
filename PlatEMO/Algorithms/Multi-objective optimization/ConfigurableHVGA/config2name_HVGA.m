function name = config2name_HVGA(config)
%CONFIG2NAME_HVGA Generate variant name from standalone HVGA config struct
%
%   name = config2name_HVGA(config)
%
%   If config.name_override is set, returns that directly.
%   Otherwise auto-generates: 'HVGA' + suffix tokens.
%
%   Suffix tokens (appended when non-default):
%     FR  = fixed reference point         (ref is non-empty)
%     E{v}= non-default eta              (eta ~= 1e-3)
%     D{v}= non-default delta            (delta ~= 1e-6)

    % Override takes precedence
    if isfield(config, 'name_override') && ~isempty(config.name_override)
        name = config.name_override;
        return;
    end

    base = 'HVGA';
    suffix = '';

    % Fixed reference point
    if ~isempty(config.ref)
        suffix = [suffix 'FR'];
    end

    % Non-default eta
    if config.eta ~= 1e-3
        suffix = [suffix 'E' num2str(config.eta)];
    end

    % Non-default delta
    if config.delta ~= 1e-6
        suffix = [suffix 'D' num2str(config.delta)];
    end

    name = [base suffix];
end
