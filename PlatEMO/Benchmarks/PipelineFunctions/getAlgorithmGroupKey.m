function groupKey = getAlgorithmGroupKey(internalName)
%GETALGORITHMGROUPKEY Return a stable grouping token for an algorithm.
%
%   groupKey = getAlgorithmGroupKey(internalName)
%
%   Used to assign a common visual style (line style, marker shape) to a
%   family of HVGSA ablation variants:
%
%     NSGA-II-CHVGSAMe1, NSGA-II-CHVGSAMe4, ...  -> 'Me'
%     NSGA-II-CHVGSAMi1, NSGA-II-CHVGSAMi10      -> 'Mi'
%     NSGA-II-CHVGSAMa7                          -> 'Ma'
%     NSGA-II-CHVGSAU3                           -> 'U5'  (U2 to U5)
%     NSGA-II-CHVGSAU8                           -> 'U10' (U6 to U10)
%     NSGA-II-CHVGSAR1p1                         -> 'R'
%     NSGA-II-CHVGSA (no suffix)                 -> 'base'
%
%   Baselines and other algorithms return the full internal name so they
%   form their own singleton group.
    name = char(internalName);
    tok = regexp(name, '^.*-CHVGSA(.*)$', 'tokens', 'once');
    if isempty(tok)
        groupKey = name;
        return;
    end
    suffix = tok{1};
    if isempty(suffix)
        groupKey = 'base';
        return;
    end
    letters = regexp(suffix, '^([A-Za-z]+)', 'tokens', 'once');
    if isempty(letters)
        groupKey = suffix;
    else
        groupKey = letters{1};
        
        % Special sub-grouping logic for 'U'
        if strcmp(groupKey, 'U')
            % Extract the numeric portion immediately following the 'U'
            numTok = regexp(suffix, '^U(\d+)', 'tokens', 'once');
            if ~isempty(numTok)
                uVal = str2double(numTok{1});
                if uVal >= 2 && uVal <= 5
                    groupKey = 'U5';
                elseif uVal >= 6 && uVal <= 10
                    groupKey = 'U10';
                end
                % If uVal is outside these ranges (e.g., 1 or 11+), 
                % it safely remains 'U'.
            end
        end
    end
end