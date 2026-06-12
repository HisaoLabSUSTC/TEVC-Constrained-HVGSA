function [fig] = PreprocessProductionImage(column,height_ratio,scale)
    %% column: 1 single column
    %% height_ratio: 1:height_ratio (width:height)
    %% scale (double-column figure); single-column = 8.8 cm, double-column = 18.1 cm
    %% Before drawing
     % The scale is to make the figure more clear
    w = 8.8*scale*column; % cm
    h = w*height_ratio;   % cm
    set(groot, 'DefaultLineLineWidth', 1.2);
    set(groot, 'DefaultAxesLineWidth',1.5);
    fig = figure('Units','centimeters','Position',[0,0,w,h]);hold on;
    set(fig,'PaperUnits','centimeters','PaperSize',[w h]);
    set(fig,'PaperPosition',[0 0 w h]);
    set(fig,'PaperPositionMode','auto');
    set(fig,'Renderer','painters');
    set(gca,'FontName','Times New Roman', "FontSize",5*scale); hold on;
    set(groot, 'DefaultAxesFontName', 'Times New Roman', 'DefaultAxesFontSize', 4*scale);
end
