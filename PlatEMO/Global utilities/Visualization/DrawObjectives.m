function handle = DrawObjectives(ax, Problem)
    if ~isempty(Problem.PF)
        if ~iscell(Problem.PF)
            if Problem.M == 2
                handle = plot(ax,Problem.PF(:,1),Problem.PF(:,2),'-k','LineWidth',3);
            elseif Problem.M == 3
                handle = plot3(ax,Problem.PF(:,1),Problem.PF(:,2),Problem.PF(:,3),'-k','LineWidth',1);
            end
        else
            if Problem.M == 2
                handle = surf(ax,Problem.PF{1},Problem.PF{2},Problem.PF{3},'EdgeColor','none','FaceColor',[.85 .85 .85]);
            elseif Problem.M == 3
                handle = surf(ax,Problem.PF{1},Problem.PF{2},Problem.PF{3},'EdgeColor',[.8 .8 .8],'FaceColor','none');
            end
            set(ax,'Children',ax.Children(flip(1:end)));
        end
    elseif size(Problem.optimum,1) > 1 && Problem.M < 4
        if Problem.M == 2
            handle = plot(ax,Problem.optimum(:,1),Problem.optimum(:,2),'.k','MarkerSize', 20);
        elseif Problem.M == 3
            handle = plot3(ax,Problem.optimum(:,1),Problem.optimum(:,2),Problem.optimum(:,3),'.k');
        end
    end
end