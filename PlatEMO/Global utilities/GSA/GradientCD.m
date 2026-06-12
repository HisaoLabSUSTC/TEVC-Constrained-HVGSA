function [grad, Xsamples] = GradientCD(H, x0flat, ref, Problem, mu)
% GradientCD  centred-difference estimate of ∇H(x)
%
%   grad = GradientCD(H, x0flat, ref, Problem, mu)
%       H          – handle that maps objective vectors to a scalar
%       x0flat     – 1 × (N·D) decision vector (row)
%       ref        – reference point passed to H
%       Problem    – problem object with .Evaluation() method
%       mu         – population size used by Problem.Evaluation
%
%   Returns
%       grad       – 1 × (N·D) row vector of partial derivatives

    eps = 1e-8;                          % Matlab's machine epsilon is around 1e-15, but for safety we use 1e-8 here
    M   = numel(x0flat);                 % dimension of x

    grad = zeros(1,M);                   % preallocate

    h    = sqrt(eps) * (1 + abs(x0flat));% step per coordinate

    Xsamples = [];

    % loop over coordinates
    for i = 1:M
        % forward step
        xPlus       = x0flat;
        xPlus(i)    = xPlus(i) + h(i);
        yPlus       = Problem.Evaluation(reshape(xPlus,[],mu)').objs;
        fPlus       = H(yPlus, ref);

        % backward step
        xMinus      = x0flat;
        xMinus(i)   = xMinus(i) - h(i);
        yMinus      = Problem.Evaluation(reshape(xMinus,[],mu)').objs;
        fMinus      = H(yMinus, ref);

        Xsamples = [Xsamples; xPlus; xMinus];

        % centred finite difference
        grad(i)     = (fPlus - fMinus) / (2*h(i));
    end
end
