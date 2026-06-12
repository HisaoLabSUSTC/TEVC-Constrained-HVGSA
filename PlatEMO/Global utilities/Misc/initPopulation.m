function Population = initPopulation(Problem, HID)
%INITPOPULATION Initialize population with optional heuristic data
%
%   Population = initPopulation(Problem, HID)
%
%   If HID is "" or empty, returns Problem.Initialization().
%   Otherwise loads decision variables from HID file, evaluates them,
%   and pads with random solutions to fill Problem.N.
%
%   Input:
%     Problem - PlatEMO problem instance
%     HID     - Path to .mat file containing 'heuristic_solutions' (N x D)
%               or "" for random initialization
%
%   Output:
%     Population - SOLUTION array of size Problem.N

    if HID == ""
        Population = Problem.Initialization();
    else
        data = load(HID, 'heuristic_solutions');
        heur_decs = data.heuristic_solutions;
        initial_n = size(heur_decs, 1);
        heur_pop = Problem.Evaluation(heur_decs);
        if Problem.N - initial_n > 0
            other_pop = Problem.Initialization(Problem.N - initial_n);
        else
            other_pop = [];
        end
        Population = [heur_pop, other_pop];
    end
end
