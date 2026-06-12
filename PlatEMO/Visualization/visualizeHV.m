%% IMPORTANT: SET THESE
path = '.\Data\CGSA2';
% Problems = {ZDT1(), ZDT2(), ZDT3(), ZDT4(), ZDT4C(), ZDT6()};
% Problems = {CF1(), CF2(), CF3(), CF4()};
% Problems = {CF5(), CF6(), CF7(), CF8()};
% Problems = {CF9(), DASCMOP1(), DASCMOP2(), DASCMOP3()};
% Problems = {DASCMOP4(), DASCMOP5(), DASCMOP6(), DASCMOP7()};
% Problems = {C2_DTLZ2(), C3_DTLZ4(), DC1_DTLZ1(), DC1_DTLZ3()};
% Problems = {DC2_DTLZ3(), DC3_DTLZ1(), DC3_DTLZ3(), DTLZ8()};
% Problems = {DTLZ9(), LIRCMOP1(), LIRCMOP2(), LIRCMOP3()};
% Problems = {LIRCMOP4(), LIRCMOP5(), LIRCMOP6(), MW1()};
% Problems = {MW2(), MW3(), MW4(), MW5()};
% Problems = {MW6(), MW7(), MW8(), MW9()};
% Problems = {RWA1(), RWA2(), RWA3(), RWA4()};
% Problems = {RWA5(), RWA6(), RWA7(), RWA8()};
% Problems = {RWA9(), RWA10(), DASCMOP9(), C1_DTLZ3()};
% Problems = {DTLZ1('M', 5), DTLZ2('M', 5), DTLZ3('M', 5), DTLZ4('M', 5)};
% Problems = {DTLZ5('M', 5), DTLZ6('M', 5), DTLZ7('M', 5), WFG1('M', 5)};
% Problems = {WFG2('M', 5), WFG4('M', 5), IDTLZ1('M', 5), IDTLZ2('M', 5)};
% Problems = {IDTLZ1('M', 10), IDTLZ2('M', 10), DTLZ1('M', 10), DTLZ2('M', 10)};

rows = 2;
cols = 2; 
n_runs = 10;
hv_samples = 50;
%% SET END

n_problems = numel(Problems);

algorithm_dirs = dir(fullfile(path, '*'));
algorithm_dirs = algorithm_dirs([algorithm_dirs.isdir]);
n_algorithms = numel(algorithm_dirs) - 2;

best_HV_index = zeros(n_algorithms, n_problems);

plot_counter = 1;
timestamp_flag = 0;

options = {'-^', '-square', '-diamond', '-v'};

figure('Name', 'HV convergence graph', 'NumberTitle', 'off');

for j=1:n_problems
    problem_name = class(Problems{j});
    disp(problem_name);
    M = Problems{j}.M;
    D = Problems{j}.D;
    
    % figure('Name', problem_name, 'NumberTitle', 'off');
    subplot(rows, cols, plot_counter);
    hold on;
    options_counter = 1;
    for i=1:n_algorithms
        algorithm_name = algorithm_dirs(i+2).name; % Adjust index to skip '.' and '..' entries
        hv = zeros(hv_samples, 1);
        for k=1:n_runs
            filename = fullfile(path, algorithm_name, sprintf('%s_%s_M%d_D%d_%d.mat', algorithm_name, problem_name, M, D, k));
            
            datum = load(filename);
            hv = hv + datum.metric.HV;
        end
        hv = hv / n_runs;
        
        timestamps = cell2mat(datum.result(:,1));
    
        if timestamps(1) ~= 0
            timestamps = [0; timestamps];
            hv = [0; hv]; % Assuming HV starts from 0
        end
        
        if algorithm_name == "C_HV_CGSA_DE"
            marker_options = '-o';
            marker_color = 'red';
            line_color = 'red';
            line_width = 1.5;
        elseif algorithm_name == "C_HV_CGSA"
            marker_options = '-o';
            marker_color = 'green';
            line_color = 'green';
            line_width = 1;
        else
            marker_options = options{options_counter};
            marker_color = 'yellow';
            line_color = 'k';
            options_counter = options_counter + 1;
            line_width = 1;
        end


        if algorithm_name == "C_HV_CGSA"
            handle = plot(timestamps, hv, marker_options, ...
            'LineWidth', line_width, ...      % Thicker line
            'MarkerSize', 8, ...     % Bigger marker
            'MarkerEdgeColor', 'black', ... % Marker edge color
            'MarkerFaceColor', marker_color, ... % Marker face color (fill)
            'Color', line_color, ...
            'DisplayName', algorithm_name);     % Line color
        elseif algorithm_name == "MOEAD"
            plot(timestamps, hv, marker_options, ...
            'LineWidth', line_width, ...      % Thicker line
            'MarkerSize', 8, ...     % Bigger marker
            'MarkerEdgeColor', 'black', ... % Marker edge color
            'MarkerFaceColor', marker_color, ... % Marker face color (fill)
            'Color', line_color, ...
            'DisplayName', "MOEA-D/TCH");          % Line color
        elseif algorithm_name == "NSGAII"
            plot(timestamps, hv, marker_options, ...
            'LineWidth', line_width, ...      % Thicker line
            'MarkerSize', 8, ...     % Bigger marker
            'MarkerEdgeColor', 'black', ... % Marker edge color
            'MarkerFaceColor', marker_color, ... % Marker face color (fill)
            'Color', line_color, ...
            'DisplayName', "NSGA-II");          % Line color
        elseif algorithm_name == "NSGAIII"
            plot(timestamps, hv, marker_options, ...
            'LineWidth', line_width, ...      % Thicker line
            'MarkerSize', 8, ...     % Bigger marker
            'MarkerEdgeColor', 'black', ... % Marker edge color
            'MarkerFaceColor', marker_color, ... % Marker face color (fill)
            'Color', line_color, ...
            'DisplayName', "NSGA-III");          % Line color
        else
            plot(timestamps, hv, marker_options, ...
            'LineWidth', line_width, ...      % Thicker line
            'MarkerSize', 8, ...     % Bigger marker
            'MarkerEdgeColor', 'black', ... % Marker edge color
            'MarkerFaceColor', marker_color, ... % Marker face color (fill)
            'Color', line_color, ...
            'DisplayName', algorithm_name);          % Line color
        end
    end

    uistack(handle, 'top');

    xlabel('Function Evaluations', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Hypervolume (HV)', 'FontSize', 12, 'FontWeight', 'bold');
    title(problem_name, 'FontSize', 14, 'FontWeight', 'bold');
    xlim([0, timestamps(end)+100]);
    grid on;
    legend('show', 'Location', 'best');
    hold off;

    fontsize(16, "points");

    plot_counter = plot_counter + 1;
end



function DrawObj(ax, Population, Problem)
    axes(ax);

    % ax = Draw(Population.objs,{'\it f\rm_1','\it f\rm_2','\it f\rm_3'});
    Draw(ax, Population.objs, {'\it f\rm_1', '\it f\rm_2', '\it f\rm_3'});

    if ~isempty(Problem.PF)
        hold(ax, 'on');
        if ~iscell(Problem.PF)
            if Problem.M == 2
                plot(ax,Problem.PF(:,1),Problem.PF(:,2),'-k','LineWidth',1);
            elseif Problem.M == 3
                plot3(ax,Problem.PF(:,1),Problem.PF(:,2),Problem.PF(:,3),'-k','LineWidth',1);
            end
        else
            if Problem.M == 2
                surf(ax,Problem.PF{1},Problem.PF{2},Problem.PF{3},'EdgeColor','none','FaceColor',[.85 .85 .85]);
            elseif Problem.M == 3
                surf(ax,Problem.PF{1},Problem.PF{2},Problem.PF{3},'EdgeColor',[.8 .8 .8],'FaceColor','none');
            end
            set(ax,'Children',ax.Children(flip(1:end)));
        end
        hold(ax, 'off');
    elseif size(Problem.optimum,1) > 1 && Problem.M < 4
        hold(ax, 'on');
        if Problem.M == 2
            plot(ax,Problem.optimum(:,1),Problem.optimum(:,2),'.k');
        elseif Problem.M == 3
            plot3(ax,Problem.optimum(:,1),Problem.optimum(:,2),Problem.optimum(:,3),'.k');
        end
        hold(ax, 'off');
    end
end


function currentAxes = Draw(ax, Data,varargin)
    if size(Data,2) == 1
        Data = [(1:size(Data,1))',Data];
    end
    set(ax,'FontName','Times New Roman','FontSize',13,'NextPlot','add','Box','on','View',[0 90],'GridLineStyle','none');
    if islogical(Data)
        [ax.XLabel.String,ax.YLabel.String,ax.ZLabel.String] = deal('Solution No.','Dimension No.',[]);
    elseif size(Data,2) > 3
        [ax.XLabel.String,ax.YLabel.String,ax.ZLabel.String] = deal('Dimension No.','Value',[]);
    elseif ~isempty(varargin) && iscell(varargin{end})
        [ax.XLabel.String,ax.YLabel.String,ax.ZLabel.String] = deal(varargin{end}{:});
    end
    if ~isempty(varargin) && iscell(varargin{end})
        varargin = varargin(1:end-1);
    end
    if isempty(varargin)
        if islogical(Data)
            varargin = {'EdgeColor','none'};
        elseif size(Data,2) == 2
            varargin = {'o','MarkerSize',6,'Marker','o','Markerfacecolor',[.7 .7 .7],'Markeredgecolor',[.4 .4 .4]};
        elseif size(Data,2) == 3
            varargin = {'o','MarkerSize',8,'Marker','o','Markerfacecolor',[.7 .7 .7],'Markeredgecolor',[.4 .4 .4]};
        elseif size(Data,2) > 3
            varargin = {'-','Color',[.5 .5 .5],'LineWidth',2};
        end
    end
    if islogical(Data)
        C = zeros(size(Data)) + 0.6;
        C(~Data) = 1;
        surf(ax,zeros(size(Data')),repmat(C',1,1,3),varargin{:});
    elseif size(Data,2) == 2
        plot(ax,Data(:,1),Data(:,2),varargin{:});
    elseif size(Data,2) == 3
        plot3(ax,Data(:,1),Data(:,2),Data(:,3),varargin{:});
        view(ax,[135 30]);
    elseif size(Data,2) > 3
        Label = repmat([0.99,2:size(Data,2)-1,size(Data,2)+0.01],size(Data,1),1);
        Data(2:2:end,:)  = fliplr(Data(2:2:end,:));
        Label(2:2:end,:) = fliplr(Label(2:2:end,:));
        plot(ax,reshape(Label',[],1),reshape(Data',[],1),varargin{:});
    end
    axis(ax,'tight');
    set(ax.Toolbar,'Visible','off');
    set(ax.Toolbar,'Visible','on');

    currentAxes = ax;
end