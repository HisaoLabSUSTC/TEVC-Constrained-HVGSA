function [min_CV, avg_CV, max_CV] = TotalCV(Cons)    
    Cons(Cons < 0) = 0;
    CV = sum(Cons, 2);
    
    min_CV = min(CV);
    avg_CV = sum(CV) / numel(CV);
    max_CV = max(CV);
end

