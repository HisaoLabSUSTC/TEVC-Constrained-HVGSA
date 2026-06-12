function X = Unflatten(Xflat, N)
    % flat -> nonflat: reshape(flat, [], N)'
    X = reshape(Xflat, [], N)';
    % output: [N (popSize), M (objDim)]
end

