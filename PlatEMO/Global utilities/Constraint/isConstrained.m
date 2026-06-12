function flag = isConstrained(Problem)
    [C, ~, ~] = ExtractConstraintInformation(Problem);
    if C == 0
        flag = 0;
    else
        flag = 1;
    end
end