function generatePopulationFigures(algorithms, problemNames, isFeasible)
%GENERATEPOPULATIONFIGURES Generate PDF of median-run population scatter plots.
%
%   generatePopulationFigures(algorithms, problemNames, isFeasible)
%
%   Produces a LaTeX document (IEEEtran journal format) with one figure*
%   per problem showing the reference Pareto front and each algorithm's
%   median-run population side by side. Only feasible problems (which have
%   reference PFs) are included.
%
%   Input:
%     algorithms   - Cell array of algorithm specs (handles or config cells)
%     problemNames - Cell array of problem name strings
%     isFeasible   - Logical vector (true = feasible, false = infeasible)
%
%   Output:
%     Writes ./PopulationFigures.tex and compiles to ./PopulationFigures.pdf
%
%   Prerequisites:
%     visualizeResults() must have run first to generate PNG images in
%     ./Visualization/images/

    fprintf('=== Generating Population Figures PDF ===\n');

    imageDir = './Visualization/images';
    maxPerRow = 4;  % Maximum subfigures per row

    algorithmNames = cellfun(@(a) getAlgorithmName(a), algorithms, ...
        'UniformOutput', false);

    %% Only include feasible problems (which have reference PF images)
    feasibleProblems = problemNames(isFeasible);

    if isempty(feasibleProblems)
        fprintf('  No feasible problems to include.\n');
        return;
    end

    %% Check that image directory exists
    if ~exist(imageDir, 'dir')
        warning('generatePopulationFigures:NoImages', ...
            'Image directory not found: %s\nRun visualizeResults() first.', imageDir);
        return;
    end

    %% Open output file
    texPath = './PopulationFigures.tex';
    fid = fopen(texPath, 'w');
    if fid == -1
        error('Could not open %s for writing.', texPath);
    end
    cleanupObj = onCleanup(@() fclose(fid));

    %% Write preamble
    writePreamble(fid);

    %% Generate one figure* per feasible problem
    figCount = 0;
    for fi = 1:numel(feasibleProblems)
        prob = feasibleProblems{fi};
        probField = matlab.lang.makeValidName(prob);

        % Collect available images for this problem
        [pfPath, algPaths, algLabels] = collectImages(imageDir, ...
            probField, algorithmNames);

        if isempty(pfPath) && isempty(algPaths)
            fprintf('  Skipping %s: no images found.\n', prob);
            continue;
        end

        figCount = figCount + 1;

        % Insert \clearpage every 2 figures to manage page breaks
        if figCount > 1 && mod(figCount - 1, 2) == 0
            fprintf(fid, '\\clearpage\n\n');
        end

        writeFigure(fid, prob, pfPath, algPaths, algLabels, maxPerRow, ...
            imageDir, figCount);
    end

    if figCount == 0
        fprintf('  No images found for any problem. Aborting.\n');
        return;
    end

    %% Write postamble
    fprintf(fid, '\n\\end{document}\n');

    fprintf('  Written to: %s\n', texPath);

    %% Compile LaTeX
    fprintf('  Compiling LaTeX...\n');
    [status, cmdout] = system('pdflatex -interaction=nonstopmode PopulationFigures.tex');
    if status == 0
        fprintf('  Compilation successful: PopulationFigures.pdf\n');
    else
        fprintf('  LaTeX compilation failed:\n%s\n', cmdout);
    end

    fprintf('=== Population figures generation complete ===\n');
end

%% ==================== Preamble ====================

function writePreamble(fid)
    fprintf(fid, '\\documentclass[journal]{IEEEtran}\n');
    fprintf(fid, '\\usepackage{graphicx}\n');
    fprintf(fid, '\\usepackage[caption=false]{subfig}\n');
    fprintf(fid, '\\usepackage{booktabs}\n');
    fprintf(fid, '\n');
    fprintf(fid, '\\begin{document}\n\n');
end

%% ==================== Image Collection ====================

function [pfPath, algPaths, algLabels] = collectImages(imageDir, ...
    probField, algorithmNames)
%COLLECTIMAGES Find available PF and population images for a problem.
%   Returns relative paths suitable for \includegraphics.

    pfPath = '';
    algPaths = {};
    algLabels = {};

    % Check for reference PF image
    pfFile = sprintf('PF-%s.png', probField);
    if exist(fullfile(imageDir, pfFile), 'file')
        pfPath = [imageDir '/' pfFile];
    end

    % Check for each algorithm's population image
    for j = 1:numel(algorithmNames)
        algName = algorithmNames{j};
        popFile = sprintf('Pop-%s-%s.png', algName, probField);
        if exist(fullfile(imageDir, popFile), 'file')
            algPaths{end+1} = [imageDir '/' popFile]; %#ok<AGROW>
            algLabels{end+1} = getAlgorithmDisplayName(algName); %#ok<AGROW>
        end
    end
end

%% ==================== Figure Generation ====================

function writeFigure(fid, probName, pfPath, algPaths, algLabels, ...
    maxPerRow, ~, figCount)
%WRITEFIGURE Write one figure* environment for a problem.

    % Total number of subfigures: PF (if present) + algorithm count
    hasPF = ~isempty(pfPath);
    numSubfigs = hasPF + numel(algPaths);

    if numSubfigs == 0
        return;
    end

    % Compute minipage width: fit up to maxPerRow per row with spacing
    imgsPerRow = min(numSubfigs, maxPerRow);
    mpWidth = 0.9 / imgsPerRow;

    fprintf(fid, '\\begin{figure*}[!t]\n');
    fprintf(fid, '\\centering\n');

    % Position counter for row-break logic
    posIdx = 0;

    % First subfigure: reference Pareto front
    if hasPF
        posIdx = posIdx + 1;
        writeSubfigure(fid, pfPath, 'True Pareto Front', ...
            posIdx, mpWidth, imgsPerRow, posIdx);
    end

    % Subsequent subfigures: each algorithm's population
    for k = 1:numel(algPaths)
        posIdx = posIdx + 1;
        displayName = escapeLatex(algLabels{k});
        writeSubfigure(fid, algPaths{k}, displayName, ...
            posIdx, mpWidth, imgsPerRow, posIdx);
    end

    fprintf(fid, '\n');

    % Caption (display uses RCM naming; label uses lower-case internal name)
    probDisplay = escapeLatex(getProblemDisplayName(probName));
    fprintf(fid, '\\caption{Median-run populations on %s.}\n', probDisplay);
    fprintf(fid, '\\label{fig:pop-%s}\n', lower(probName));
    fprintf(fid, '\\end{figure*}\n\n');
end

function writeSubfigure(fid, imgPath, subcaption, ~, ...
    mpWidth, imgsPerRow, posInFig)
%WRITESUBFIGURE Write one \subfloat subfigure.

    % Use forward slashes for LaTeX paths
    imgPath = strrep(imgPath, '\', '/');

    % Line break before new row (but not before the first subfigure)
    if posInFig > 1 && mod(posInFig - 1, imgsPerRow) == 0
        fprintf(fid, '\\\\[0.5em]\n');
    end

    fprintf(fid, '\\subfloat[%s]{', subcaption);
    fprintf(fid, '\\includegraphics[width=%.3f\\linewidth]{%s}', mpWidth, imgPath);
    fprintf(fid, '}\\hfill\n');
end

%% ==================== LaTeX Utilities ====================

function escaped = escapeLatex(str)
%ESCAPELATEX Escape special LaTeX characters in a string.
    escaped = strrep(str, '_', '\_');
    escaped = strrep(escaped, '&', '\&');
    escaped = strrep(escaped, '%', '\%');
    escaped = strrep(escaped, '#', '\#');
end
