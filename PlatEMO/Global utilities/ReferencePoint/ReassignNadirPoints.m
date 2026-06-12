fprintf('Starting extended nadir points computation and reassignment...\n');

% Configuration
C = 1.2;  % Extension factor for nadir points
fprintf('Using extension factor C = %.2f\n\n', C);

% Define problem list
problems = getProblemList();

% Define directories
dirs = struct();
dirs.info = fullfile("Info/");
dirs.ref = fullfile("Problems/Multi-objective optimization/RWMOPs/RefPoints/");

% Validate directories
if ~validateDirectories(dirs)
    return;
end

% Process each problem
stats = processAllProblems(problems, dirs, C);

% Display summary
displaySummary(stats);


%% ========================= PROBLEM DEFINITION =========================

function problems = getProblemList()
    % Return the list of all RWMOP problems
    problems = {@RWMOP1,@RWMOP2,@RWMOP3,@RWMOP4,@RWMOP5,@RWMOP6,@RWMOP7,...
                @RWMOP8,@RWMOP9,@RWMOP10,@RWMOP11,@RWMOP12,@RWMOP13,...
                @RWMOP14,@RWMOP15,@RWMOP16,@RWMOP17,@RWMOP18,@RWMOP19,...
                @RWMOP20,@RWMOP21,@RWMOP22,@RWMOP23,@RWMOP24,@RWMOP25,...
                @RWMOP26,@RWMOP27,@RWMOP28,@RWMOP29,@RWMOP30,@RWMOP31,...
                @RWMOP32,@RWMOP33,@RWMOP34,@RWMOP35,@RWMOP36,@RWMOP37,...
                @RWMOP38,@RWMOP39,@RWMOP40,@RWMOP41,@RWMOP42,@RWMOP43,...
                @RWMOP44,@RWMOP45,@RWMOP46,@RWMOP47,@RWMOP48,@RWMOP49,@RWMOP50};
end

%% ========================= DIRECTORY VALIDATION =========================

function isValid = validateDirectories(dirs)
    % Validate that required directories exist
    
    isValid = true;
    
    % Check Info directory
    if ~exist(dirs.info, 'dir')
        fprintf('Error: Info directory does not exist: %s\n', dirs.info);
        fprintf('Please ensure the Info directory exists with ideal_i.txt and nadir_i.txt files.\n');
        isValid = false;
        return;
    end
    
    % Check RefPoints directory
    if ~exist(dirs.ref, 'dir')
        fprintf('Error: RefPoints directory does not exist: %s\n', dirs.ref);
        fprintf('Please ensure the PlatEMO problem structure is properly set up.\n');
        isValid = false;
        return;
    end
    
    fprintf('Directory validation complete.\n');
    fprintf('  Info directory: %s\n', dirs.info);
    fprintf('  RefPoints directory: %s\n', dirs.ref);
    fprintf('\n');
end

%% ========================= MAIN PROCESSING =========================

function stats = processAllProblems(problems, dirs, C)
    % Process all problems and compute extended nadir points
    
    % Initialize statistics
    stats = initializeStatistics(length(problems));
    
    fprintf('Processing %d problems...\n\n', stats.total);
    
    % Process each problem
    for p = 1:length(problems)
        try
            result = processSingleProblem(problems{p}, dirs, p, C);
            updateStatistics(stats, result, p);
            
        catch ME
            stats.errors = stats.errors + 1;
            stats.errorList{end+1} = sprintf('RWMOP%d: %s', p, ME.message);
            fprintf('  Error processing RWMOP%d: %s\n', p, ME.message);
        end
    end
    
    fprintf('\n');
end

function stats = initializeStatistics(numProblems)
    % Initialize statistics structure
    stats = struct();
    stats.total = numProblems;
    stats.updated = 0;
    stats.skipped_missing_ideal = 0;
    stats.skipped_missing_nadir = 0;
    stats.skipped_missing_both = 0;
    stats.errors = 0;
    stats.updatedList = {};
    stats.skippedList = {};
    stats.errorList = {};
end

function updateStatistics(stats, result, problemIndex)
    % Update statistics based on processing result
    
    switch result.status
        case 'updated'
            stats.updated = stats.updated + 1;
            stats.updatedList{end+1} = sprintf('RWMOP%d', problemIndex);
            
        case 'missing_both'
            stats.skipped_missing_both = stats.skipped_missing_both + 1;
            stats.skippedList{end+1} = sprintf('RWMOP%d (both files missing)', problemIndex);
            
        case 'missing_ideal'
            stats.skipped_missing_ideal = stats.skipped_missing_ideal + 1;
            stats.skippedList{end+1} = sprintf('RWMOP%d (ideal missing)', problemIndex);
            
        case 'missing_nadir'
            stats.skipped_missing_nadir = stats.skipped_missing_nadir + 1;
            stats.skippedList{end+1} = sprintf('RWMOP%d (nadir missing)', problemIndex);
    end
end

function result = processSingleProblem(problemHandle, dirs, problemIndex, C)
    % Process a single problem and compute extended nadir point
    
    result = struct();
    result.status = '';
    result.message = '';
    
    % Create problem instance
    Problem = problemHandle();
    
    % Get problem index from class name
    idx = sscanf(class(Problem), "RWMOP%d");
    
    % Verify index consistency
    if idx ~= problemIndex
        warning('Index mismatch: Expected %d, got %d for %s', ...
                problemIndex, idx, class(Problem));
    end
    
    % Define file paths
    idealSourceFile = fullfile(dirs.info, sprintf("ideal_%d.txt", idx));
    nadirSourceFile = fullfile(dirs.info, sprintf("nadir_%d.txt", idx));
    nadirTargetFile = fullfile(dirs.ref, sprintf("nadir_%d.txt", idx));
    
    % Check if both source files exist
    hasIdeal = exist(idealSourceFile, 'file');
    hasNadir = exist(nadirSourceFile, 'file');
    
    if ~hasIdeal && ~hasNadir
        fprintf('  RWMOP%02d: Both ideal and nadir files missing in Info/ - skipping\n', idx);
        result.status = 'missing_both';
        return;
    elseif ~hasIdeal
        fprintf('  RWMOP%02d: ideal_%d.txt missing in Info/ - cannot compute extended nadir\n', idx, idx);
        result.status = 'missing_ideal';
        return;
    elseif ~hasNadir
        fprintf('  RWMOP%02d: nadir_%d.txt missing in Info/ - cannot compute extended nadir\n', idx, idx);
        result.status = 'missing_nadir';
        return;
    end
    
    % Read ideal and nadir points
    idealPoint = readPointFile(idealSourceFile);
    nadirPoint = readPointFile(nadirSourceFile);
    
    % Validate data
    if isempty(idealPoint) || isempty(nadirPoint)
        error('Failed to read ideal or nadir point data');
    end
    
    if length(idealPoint) ~= length(nadirPoint)
        error('Dimension mismatch: ideal has %d dimensions, nadir has %d dimensions', ...
              length(idealPoint), length(nadirPoint));
    end
    
    % Compute extended nadir point
    extendedNadir = computeExtendedNadir(idealPoint, nadirPoint, C);
    
    % Write extended nadir to target file
    success = writeExtendedNadir(nadirTargetFile, extendedNadir, idx);
    
    if success
        fprintf('  RWMOP%02d: Successfully updated with extended nadir point\n', idx);
        fprintf('           Ideal: [%s]\n', formatVector(idealPoint));
        fprintf('           Original Nadir: [%s]\n', formatVector(nadirPoint));
        fprintf('           Extended Nadir (C=%.2f): [%s]\n', C, formatVector(extendedNadir));
        result.status = 'updated';
    else
        error('Failed to write extended nadir point');
    end
end

%% ========================= COMPUTATION FUNCTIONS =========================

function extendedNadir = computeExtendedNadir(idealPoint, nadirPoint, C)
    % Compute extended nadir point using the formula:
    % extended_nadir = ideal + C * (nadir - ideal)
    
    % Ensure vectors are row vectors for consistency
    idealPoint = idealPoint(:)';
    nadirPoint = nadirPoint(:)';
    
    % Compute extended nadir
    extendedNadir = idealPoint + C * (nadirPoint - idealPoint);
    
    % Handle any infinite or invalid values
    if any(isinf(extendedNadir)) || any(isnan(extendedNadir))
        warning('Extended nadir contains infinite or NaN values');
    end
end

%% ========================= FILE OPERATIONS =========================

function data = readPointFile(filename)
    % Read a point file and return the data vector
    
    data = [];
    
    try
        fid = fopen(filename, 'r');
        if fid == -1
            error('Cannot open file: %s', filename);
        end
        
        % Read all numbers from file
        data = fscanf(fid, '%f', [inf]);
        fclose(fid);
        
        % Ensure it's a row vector
        data = data(:)';
        
        if isempty(data)
            error('File is empty: %s', filename);
        end
        
    catch ME
        if exist('fid', 'var') && fid ~= -1
            fclose(fid);
        end
        error('Failed to read file %s: %s', filename, ME.message);
    end
end

function success = writeExtendedNadir(targetFile, extendedNadir, idx)
    % Write extended nadir point to file
    
    success = false;
    
    try
        % Backup existing file if it exists
        if exist(targetFile, 'file')
            backupFile(targetFile, idx, 'nadir');
        end
        
        % Write new extended nadir point
        fid = fopen(targetFile, 'w');
        if fid == -1
            error('Cannot open file for writing: %s', targetFile);
        end
        
        % Write with high precision
        fprintf(fid, [repmat('%.15f ', 1, length(extendedNadir)-1) '%.15f\n'], extendedNadir);
        fclose(fid);
        
        success = true;
        
    catch ME
        if exist('fid', 'var') && fid ~= -1
            fclose(fid);
        end
        error('Failed to write extended nadir: %s', ME.message);
    end
end

function backupFile(filename, idx, type)
    % Create a backup of the original file
    
    [path, ~, ext] = fileparts(filename);
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    backupName = fullfile(path, sprintf('%s_%d_backup_%s%s', type, idx, timestamp, ext));
    
    try
        copyfile(filename, backupName);
        fprintf('           Backed up original to: %s\n', backupName);
    catch ME
        warning('Could not create backup: %s', ME.message);
    end
end

%% ========================= UTILITY FUNCTIONS =========================

function str = formatVector(vec)
    % Format a vector for display with limited precision
    
    if length(vec) <= 5
        % Show all elements for small vectors
        str = sprintf('%.4f ', vec);
    else
        % Show first 3 and last 2 for larger vectors
        str = sprintf('%.4f %.4f %.4f ... %.4f %.4f', ...
                     vec(1), vec(2), vec(3), vec(end-1), vec(end));
    end
    
    % Remove trailing space
    str = strtrim(str);
end

function displaySummary(stats)
    % Display summary of the reassignment process
    
    fprintf('EXTENDED NADIR REASSIGNMENT SUMMARY\n');
    fprintf('Total problems processed: %d\n', stats.total);
    fprintf('Files updated with extended nadir: %d\n', stats.updated);
    fprintf('Files skipped (missing both): %d\n', stats.skipped_missing_both);
    fprintf('Files skipped (missing ideal): %d\n', stats.skipped_missing_ideal);
    fprintf('Files skipped (missing nadir): %d\n', stats.skipped_missing_nadir);
    fprintf('Errors encountered: %d\n', stats.errors);
    
    if ~isempty(stats.updatedList)
        fprintf('\nSuccessfully updated problems:\n');
        for i = 1:length(stats.updatedList)
            fprintf('  ✓ %s\n', stats.updatedList{i});
        end
    end
    
    if ~isempty(stats.skippedList)
        fprintf('\nSkipped problems:\n');
        for i = 1:length(stats.skippedList)
            fprintf('  - %s\n', stats.skippedList{i});
        end
    end
    
    if ~isempty(stats.errorList)
        fprintf('\nErrors:\n');
        for i = 1:length(stats.errorList)
            fprintf('  ✗ %s\n', stats.errorList{i});
        end
    end
    
    fprintf('\nProcess complete.\n');
end
