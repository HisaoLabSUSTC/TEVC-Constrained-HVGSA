%% RecalibrateReferencePoints.m

% List of all problems
problems = {@RWMOP1,@RWMOP2,@RWMOP3,@RWMOP4,@RWMOP5,@RWMOP6,@RWMOP7,...
            @RWMOP8,@RWMOP9,@RWMOP10,@RWMOP11,@RWMOP12,@RWMOP13,...
            @RWMOP14,@RWMOP15,@RWMOP16,@RWMOP17,@RWMOP18,@RWMOP19,...
            @RWMOP20,@RWMOP21,@RWMOP22,@RWMOP23,@RWMOP24,@RWMOP25,...
            @RWMOP26,@RWMOP27,@RWMOP28,@RWMOP29,@RWMOP30,@RWMOP31,...
            @RWMOP32,@RWMOP33,@RWMOP34,@RWMOP35,@RWMOP36,@RWMOP37,...
            @RWMOP38,@RWMOP39,@RWMOP40,@RWMOP41,@RWMOP42,@RWMOP43,...
            @RWMOP44,@RWMOP45,@RWMOP46,@RWMOP47,@RWMOP48,@RWMOP49,@RWMOP50};

data_dir = fullfile("Data/");
info_dir = fullfile("Info/");

subdirs = dir(data_dir);
subdirs = subdirs([subdirs.isdir]);
subdirs = subdirs(~ismember({subdirs.name}, {'.', '..'}));

% Use parfor to parallelize across problems
parfor p = 1:length(problems)
    Problem_handle = problems{p};
    Problem = Problem_handle();

    % Get problem index from class name
    idx = sscanf(class(Problem), "RWMOP%d");

    nadir_point = ones(1, Problem.M) * -inf;
    fprintf("Handling problem %s\n", class(Problem));
    % Loop through each algorithm subdir
    feas_objs_all = [];
    for i = 1:length(subdirs)
        algo_name = subdirs(i).name;
        fprintf("Under algorithm %s\n", algo_name);
        data_subdir = fullfile(data_dir, algo_name);
        mat_files = dir(fullfile(data_subdir, sprintf('*_%s_*.mat', class(Problem))));

        for j = 1:length(mat_files)
            data = load(fullfile(data_subdir, mat_files(j).name));
            result_data = data.result;
            num_gen = size(result_data, 1);

            for g = num_gen-5:num_gen
                population = result_data{g, 2};
                cons = population.cons;
                cons(cons < 0) = 0;
                cv = sum(cons, 2);
                feas_idx = find(cv <= 0);
                feas_pop = population(feas_idx);
                feas_objs = feas_pop.objs;
                feas_objs_all = [feas_objs_all; feas_objs];
                [NDF, ~] = NDSort(feas_objs_all, 1);
                feas_objs_all = feas_objs_all(NDF==1,:);
            end
            fprintf("Feasible objectives size: (%d, %d)", size(feas_objs_all,1), size(feas_objs_all,2));
        end
    end

    if ~isempty(feas_objs_all)
        [NDFront, ~] = NDSort(feas_objs_all, 1);
        NDFront_objs = feas_objs_all(NDFront==1,:);
        nadir_point = EstimateNadirPoint(NDFront_objs, 1);
        ideal_point = EstimateNadirPoint(NDFront_objs, 0);
    end

    % If nadir was updated, write it back to file
    if ~(any(isinf(nadir_point)))
        nadir_filename = fullfile(info_dir, sprintf("nadir_%d.txt", idx));
        nfid = fopen(nadir_filename, 'w');
        fprintf(nfid, [repmat('%.15f ', 1, Problem.M) '\n'], nadir_point);
        fclose(nfid);

        ideal_filename = fullfile(info_dir, sprintf("ideal_%d.txt", idx));
        ifid = fopen(ideal_filename, 'w');
        fprintf(ifid, [repmat('%.15f ', 1, Problem.M) '\n'], ideal_point);
        fclose(ifid);
    end
end