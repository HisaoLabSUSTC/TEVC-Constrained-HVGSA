% ===============================
% Compute ideal points for RWMOPs
% ===============================

% List of all problems
problems = {@RWMOP1,@RWMOP2,@RWMOP3,@RWMOP4,@RWMOP5,@RWMOP6,@RWMOP7,...
            @RWMOP8,@RWMOP9,@RWMOP10,@RWMOP11,@RWMOP12,@RWMOP13,...
            @RWMOP14,@RWMOP15,@RWMOP16,@RWMOP17,@RWMOP18,@RWMOP19,...
            @RWMOP20,@RWMOP21,@RWMOP22,@RWMOP23,@RWMOP24,@RWMOP25,...
            @RWMOP26,@RWMOP27,@RWMOP28,@RWMOP29,@RWMOP30,@RWMOP31,...
            @RWMOP32,@RWMOP33,@RWMOP34,@RWMOP35,@RWMOP36,@RWMOP37,...
            @RWMOP38,@RWMOP39,@RWMOP40,@RWMOP41,@RWMOP42,@RWMOP43,...
            @RWMOP44,@RWMOP45,@RWMOP46,@RWMOP47,@RWMOP48,@RWMOP49,@RWMOP50};

ref_dir  = fullfile("Problems/Multi-objective optimization/RWMOPs/RefPoints");
data_dir = fullfile("Data/");

% Enumerate algorithm subdirectories
subdirs = dir(data_dir);
subdirs = subdirs([subdirs.isdir]);
subdirs = subdirs(~ismember({subdirs.name}, {'.', '..'}));

nProblems = numel(problems);

% --- Setup progress bar ---
q = parallel.pool.DataQueue;
progressCount = 0;
tStart = tic;
wb = waitbar(0, sprintf('Processing 0/%d problems...', nProblems));

afterEach(q, @(msg) updateWaitbar(msg));


% --- Main loop (parallel) ---
parfor p = 1:nProblems
    try
        Problem_handle = problems{p};
        Problem = Problem_handle();

        % Get problem index from class name (RWMOPxx)
        idx = sscanf(class(Problem), "RWMOP%d");
        fprintf('[DEBUG] Starting problem %d (%s)\n', idx, class(Problem));

        % Start with +inf (so min() works)
        ideal_point = ones(1, Problem.M) * inf;

        % Loop through each algorithm subdir
        for i = 1:length(subdirs)
            data_subdir = fullfile(data_dir, subdirs(i).name);
            mat_files   = dir(fullfile(data_subdir, sprintf('*_%s_*.mat', class(Problem))));

            for j = 1:length(mat_files)
                data = load(fullfile(data_subdir, mat_files(j).name));
                result_data = data.result;
                num_gen = size(result_data, 1);

                for g = 1:num_gen
                    population = result_data{g, 2};
                    cons = population.cons;
                    cons(cons < 0) = 0;
                    cv = sum(cons, 2);
                    feas_idx = find(cv <= 0);

                    if ~isempty(feas_idx)
                        feas_pop  = population(feas_idx);
                        feas_objs = feas_pop.objs;
                        ideal_point = min([ideal_point; feas_objs], [], 1);
                    end
                end
            end
        end

        % --- Write ideal point if valid ---
        if all(isfinite(ideal_point))
            filename = fullfile(ref_dir, sprintf("ideal_%d.txt", idx));
            fid = fopen(filename, 'w');
            fprintf(fid, [repmat('%.15f ', 1, Problem.M) '\n'], ideal_point);
            fclose(fid);
            fprintf('[DEBUG] Wrote ideal point for problem %d (%s)\n', idx, class(Problem));
        else
            fprintf('[DEBUG] No feasible solutions for problem %d (%s)\n', idx, class(Problem));
        end

        % notify progress
        send(q, sprintf('Problem %d', idx));

    catch ME
        fprintf(2,'[ERROR] Problem %d failed: %s\n', p, ME.message);
        send(q, sprintf('Problem %d (error)', p));
    end
end

close(wb);
disp('All problems processed.');

function updateWaitbar(msg)
    progressCount = progressCount + 1;
    elapsed = toc(tStart);
    estTotal = elapsed / progressCount * nProblems;
    estRemain = estTotal - elapsed;
    waitbar(progressCount/nProblems, wb, ...
        sprintf('Processed %d/%d (last: %s) - ETA %.1fs', ...
        progressCount, nProblems, msg, estRemain));
end
