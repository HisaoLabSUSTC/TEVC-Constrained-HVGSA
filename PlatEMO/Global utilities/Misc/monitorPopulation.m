function monitorPopulation(Population, iteration)
    % Target pattern
    target = [-3.89082, 0.84924];
    tolerance = 5e-6;
    
    % Check for matches
    decs = Population.decs;
    differences = abs(decs - target);
    row_matches = all(differences < tolerance, 2);
    
    if any(row_matches)
        indices = find(row_matches);
        fprintf('\n*** ALERT: Target pattern detected at iteration %d ***\n', iteration);
        fprintf('Indices: %s\n', mat2str(indices));
        
        % Show the actual values
        for idx = indices'
            fprintf('Row %d: [%.10f, %.10f] (diff: [%.2e, %.2e])\n', ...
                idx, decs(idx,1), decs(idx,2), ...
                differences(idx,1), differences(idx,2));
        end
        
        % Optional: Set a breakpoint here for debugging
        % dbstop in monitorPopulation at 27
        pause(1);
    end
end