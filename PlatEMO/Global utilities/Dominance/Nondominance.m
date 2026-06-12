function [indices, ExPop] = Nondominance(FixPop, Pop)

    FixObjs = FixPop.objs;
    PopObjs = Pop.objs;
    [DiffObjs, iDiff] = setdiff(PopObjs, FixObjs, "rows");

    FixBlock = permute(FixObjs, [3 2 1]);

    DiffPop = Pop(iDiff);

    dominated = any(all(DiffObjs > FixBlock(:,:,:), 2), 3);
    dominator = any(all(DiffObjs < FixBlock(:,:,:), 2), 3);

    % dominated_idx = iDiff(dominated);
    % dominator_idx = iDiff(dominator);
    
    keep_idx = find(~(dominated | dominator));

    kept_pop = DiffPop(keep_idx);

    [FrontNo,~] = NDSort(kept_pop.objs, 1);
    ND_idx = find(FrontNo==1);

    indices = keep_idx(ND_idx);
    kept_pop = DiffPop(keep_idx);
    ExPop = [kept_pop(ND_idx), FixPop];
end