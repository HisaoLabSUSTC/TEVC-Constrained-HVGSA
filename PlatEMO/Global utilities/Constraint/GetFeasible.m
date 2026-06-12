function feas_pop = GetFeasible(Population)
    cons = Population.cons;
    feasible_row_idx = all(cons<=0, 2);

    feas_pop = Population(feasible_row_idx);
end

