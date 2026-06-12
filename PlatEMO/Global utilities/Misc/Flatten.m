function Xflat = Flatten(X)
    % nonflat -> flat: reshape(nonflat', 1, [])
    Xflat = reshape(X', 1, []);
end
