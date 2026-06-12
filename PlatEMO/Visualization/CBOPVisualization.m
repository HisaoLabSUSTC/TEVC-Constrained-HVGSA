PROBLEM = @CBOP2;

algorithm = {@CBOPAlgorithm};
FE = 100000;

%% Saving data
% platemo('problem', PROBLEM, 'N', 100, ...
%         'maxFE', FE, 'algorithm', algorithm{:});

%% Loading data
PROBLEM = PROBLEM();
filename = sprintf("Visualization/%s_%d.mat", class(PROBLEM), FE);
wrapper = load(filename);
VisualizeCBOP(wrapper.viz_data, PROBLEM);