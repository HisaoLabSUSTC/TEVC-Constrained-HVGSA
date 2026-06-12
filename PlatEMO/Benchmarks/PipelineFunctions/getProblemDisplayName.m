function displayName = getProblemDisplayName(internalName)
%GETPROBLEMDISPLAYNAME Map internal problem names to display names.
%
%   displayName = getProblemDisplayName(internalName)
%
%   Used only for reader-facing PDF output (table rows, figure captions,
%   plot titles). Internal file paths, .mat filenames and PlatEMO handles
%   continue to use the raw RWMOP* name.
%
%   Rules:
%     RWMOP{n}  ->  RCM{n}      (e.g. RWMOP25 -> RCM25)
%     anything else             -> returned unchanged

    name = char(internalName);

    tok = regexp(name, '^RWMOP(\d+)$', 'tokens', 'once');
    if ~isempty(tok)
        displayName = ['RCM' tok{1}];
        return;
    end

    displayName = name;
end
