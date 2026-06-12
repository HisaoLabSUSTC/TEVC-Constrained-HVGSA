Problem = @CBOP2;

% mode = 'far';
mode = 'near';

if strcmp(mode, 'far')
    Initial_Decs = [2.4,2.6;4.45,2.7;5.05,2.45;6.05,2.7;7.02,2.66];
    FE = 500000;
elseif strcmp(mode, 'near')
    Initial_Decs = [0.05,-0.447;2.43,0.482;5.05,-0.203;7.88,-0.37;9.95,-0.14];
    FE = 250000;
else
    error('unknown mode');
end

HS_dir = 'ProduceImage/CBOP-HS';
%% Save heuristic initial decisions to a temporary .mat file
heuristic_solutions = Initial_Decs;

if strcmp(mode, 'far')
    HID_file = fullfile(HS_dir, 'HVGSA_FarDecs.mat');
elseif strcmp(mode, 'near')
    HID_file = fullfile(HS_dir, 'HVGSA_NearDecs.mat');
end

save(HID_file, 'heuristic_solutions');

%% Generate algorithm spec
ref_pf = [125, 125];
algorithmConfig = struct('eta', 1e-3, 'ref', ref_pf);
algorithm = generateHVGSA(algorithmConfig);
algorithm{end+1} = HID_file;


%% Run
platemo('problem', Problem, 'N', size(Initial_Decs, 1), ...
        'maxFE', FE, 'algorithm', algorithm, 'save', 1e8);

%% Visualize — reconstruct viz_data from PlatEMO-saved result
PROBLEM = Problem();
algName = config2name_HVGSA(parseHVGSAConfig(algorithmConfig));

if strcmp(mode, 'far')
    dataFile = fullfile('Data', algName, ...
        sprintf('%s_%s_M%d_D%d_1.mat', algName, class(PROBLEM), PROBLEM.M, PROBLEM.D));
elseif strcmp(mode, 'near')
    dataFile = fullfile('Data', algName, ...
        sprintf('%s_%s_M%d_D%d_2.mat', algName, class(PROBLEM), PROBLEM.M, PROBLEM.D));
end

data = load(dataFile);
result = data.result;  % Nx2 cell: {FE, Population}

nGen = size(result, 1);
viz_data = struct();
viz_data.Populations = result(:,2)';
viz_data.Iterations = num2cell(1:nGen);
viz_data.Ref = ref_pf;
viz_data.Hypervolume = cell(1, nGen);
for i = 1:nGen
    pop = result{i, 2};
    viz_data.Hypervolume{i} = FeasibleCHV(ref_pf, Flatten(pop.objs), Flatten(pop.cons));
end

VisualizeCBOP(viz_data, PROBLEM);
