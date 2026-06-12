classdef VizData < handle
    % VizData -- A visualization struct for Hybrid algorithm.
    
    properties
        populations
        GSA_pops
        eta_values
        iterations
        viz_counter
    end
    
    methods
        function obj = VizData()
            %% Constructor for VizData
            obj.populations = {};
            obj.GSA_pops = {};
            obj.eta_values = [];
            obj.iterations = [];
            obj.viz_counter = 1;
        end
        
                        % viz_data.populations{viz_counter} = Population;
                % viz_data.iterations(viz_counter) = iter_counter;
                                    % viz_data.GSA_pops{viz_counter} = struct();
                    % viz_data.eta_values(viz_counter) = 0;
                    % viz_counter = viz_counter + 1;
                %     viz_data.GSA_pops{viz_counter} = trajectory;
                % viz_data.eta_values(viz_counter) = used_eta;

        function update(obj, emoa_pop, iter, gsa_pop, etas)
            counter = obj.viz_counter;
            obj.populations{counter} = emoa_pop;
            obj.iterations(counter) = iter;
            obj.GSA_pops{counter} = gsa_pop;
            obj.eta_values(counter) = etas;
            obj.viz_counter = counter + 1;
        end
    end
end

