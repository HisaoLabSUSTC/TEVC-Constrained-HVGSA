function name = config2name_CHVGSA(config)
%CONFIG2NAME_CHVGSA Generate variant name from C-HVGSA config struct
%
%   name = config2name_CHVGSA(config)
%
%   If config.name_override is set, returns that directly.
%   Otherwise auto-generates: 'NSGA2CHVGSA' + suffix tokens.
%
%   Suffix tokens (appended when non-default):
%     WN  = without normalization    (use_normalization='off')
%     ON  = objective-only norm      (use_normalization='obj')
%     A{n}= archive size n           (Qsize!=50; A0 means archive disabled)
%     NE  = no expanded front        (use_expanded_front=false)
%     NI  = no interpolation         (use_interpolation=false)
%     S   = constant sqrt(D) step    (eta_mode='constant_sqrtD')
%     IS  = constant 1/sqrt(D) step  (eta_mode='constant_invSqrtD')
%     O   = constant one step        (eta_mode='constant_one')
%     FN  = full normalization        (gradient_method='CGSA')
%     R{c}= fixed refC value         (refC=numeric, e.g. R1p1 for 1.1)
%     Me{k} = mean sr_mode, k_min=k  (sr_mode='mean', k_min>1)
%     Mi{k} = min sr_mode, k_min=k   (sr_mode='min')
%     Ma{k} = max sr_mode, k_min=k   (sr_mode='max')
%     U{n}= fixed U value            (U_mode='fixed')

    % Override takes precedence
    if isfield(config, 'name_override') && ~isempty(config.name_override)
        name = config.name_override;
        return;
    end

    base = 'NSGA-II-CHVGSA';
    suffix = '';

    % Normalization
    if strcmp(config.use_normalization, 'on')
        suffix = [suffix 'Bn'];
    elseif strcmp(config.use_normalization, 'obj')
        suffix = [suffix 'On'];
    end

    % Archive size (only tagged when non-default; default Qsize=50 stays bare)
    if config.Qsize ~= 50
        suffix = [suffix 'A' num2str(config.Qsize)];
    end

    % Expanded front
    if ~config.use_expanded_front
        suffix = [suffix 'NE'];
    end

    % Interpolation
    if ~config.use_interpolation
        suffix = [suffix 'NI'];
    end

    % Step size mode (non-default)
    switch config.eta_mode
        case 'constant_sqrtD'
            suffix = [suffix 'S'];
        case 'constant_invSqrtD'
            suffix = [suffix 'IS'];
        case 'constant_one'
            suffix = [suffix 'O'];
    end

    % Gradient method (non-default)
    if strcmp(config.gradient_method, 'CGSA')
        suffix = [suffix 'FN'];
    end

    % Reference constant (non-default)
    if isnumeric(config.refC)
        refStr = strrep(num2str(config.refC), '.', 'p');
        suffix = [suffix 'R' refStr];
    end

    % SR mode and k_min (non-default combinations)
    if ~strcmp(config.sr_mode, 'mean') || config.k_min ~= 1
        switch config.sr_mode
            case 'mean'
                suffix = [suffix 'Me' num2str(config.k_min)];
            case 'min'
                suffix = [suffix 'Mi' num2str(config.k_min)];
            case 'max'
                suffix = [suffix 'Ma' num2str(config.k_min)];
        end
    end

    % Fixed U
    if strcmp(config.U_mode, 'fixed')
        suffix = [suffix 'U' num2str(config.U_value)];
    end

    name = [base suffix];
end
