function [radian, degree] = ComputeAngle(a, b)
    dot_product = dot(a, b);
    norm_a = norm(a);
    norm_b = norm(b);
    cos_theta = dot_product / (norm_a * norm_b);

    % Handle numerical inaccuracies by ensuring cos_theta is within [-1, 1]
    cos_theta = max(min(cos_theta, 1), -1);
    
    % Compute the angle in radians
    radian = acos(cos_theta);
    
    % Optionally, convert the angle to degrees
    degree = rad2deg(radian);
end