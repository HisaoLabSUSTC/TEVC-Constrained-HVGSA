function [problemHandles, problemNames] = parseProblemList(problems)
%PARSEPROBLEMLIST Parse RWMOP problem list into handles and names
%
%   [problemHandles, problemNames] = parseProblemList(problems)
%
%   Input:
%     problems - Cell array of function handles, e.g. {@RWMOP1, @RWMOP2, ...}
%
%   Returns:
%     problemHandles - Cell array of function handles
%     problemNames   - Cell array of string names (e.g., {'RWMOP1', 'RWMOP2', ...})
%
%   RWMOP problems have fixed M and D per problem definition, so no
%   M/D/ID vectors are needed.

    n = numel(problems);
    problemHandles = cell(1, n);
    problemNames = cell(1, n);

    for i = 1:n
        entry = problems{i};
        if isa(entry, 'function_handle')
            problemHandles{i} = entry;
            problemNames{i} = func2str(entry);
        else
            error('parseProblemList:InvalidEntry', ...
                'Entry %d must be a function handle (e.g. @RWMOP1)', i);
        end
    end
end
