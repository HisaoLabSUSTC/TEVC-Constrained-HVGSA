function displayName = getAlgorithmDisplayName(internalName)
%GETALGORITHMDISPLAYNAME Map internal algorithm names to display names.
%
%   displayName = getAlgorithmDisplayName(internalName)
%
%   Transforms file-safe internal names (used for data directories and
%   .mat files) into reader-friendly names used only for PDF output
%   (Wilcoxon tables, population figures, convergence plots, CD plots).
%
%   Rules:
%     1. Known baseline aliases (e.g. 'NSGAIIwH' -> 'NSGA-II').
%     2. CHVGSA variants: '{MOEA}-CHVGSA{suffix}' -> '{MOEA}-HVGSA-{suffix}'.
%        Empty suffix collapses to '{MOEA}-HVGSA'.
%        Example: 'NSGA-II-CHVGSAMe3' -> 'NSGA-II-HVGSA-Me3'.
%     3. Fallback: return the internal name unchanged.

    persistent baselineMap
    if isempty(baselineMap)
        baselineMap = containers.Map();
        baselineMap('NSGAIIwH')     = 'NSGA-II';
        baselineMap('CMOEACDwH')    = 'CMOEA-CD';
        baselineMap('ICMAwH')       = 'ICMA';
        baselineMap('SPEA2wH')      = 'SPEA2';
        baselineMap('SMSEMOAwH')    = 'SMS-EMOA';
        baselineMap('PPSwH')        = 'PPS';
        baselineMap('ToPwH')        = 'ToP-NSGA-II';
        baselineMap('CMOEADwH')     = 'C-MOEA/D';
        baselineMap('NSGAII')       = 'NSGA-II';
        baselineMap('CMOEACD')      = 'CMOEA-CD';
        baselineMap('ICMACHVGSA')   = 'ICMA-HVGSA';
        baselineMap('CMOEACDCHVGSA') = 'CMOEA-CD-HVGSA';
    end

    name = char(internalName);

    if isKey(baselineMap, name)
        displayName = baselineMap(name);
        return;
    end

    tok = regexp(name, '^(.*)-CHVGSA(.*)$', 'tokens', 'once');
    if ~isempty(tok)
        prefix = tok{1};
        suffix = tok{2};
        if isempty(suffix)
            displayName = sprintf('%s-HVGSA', prefix);
        else
            displayName = sprintf('%s-HVGSA-%s', prefix, suffix);
        end
        return;
    end

    displayName = name;
end
