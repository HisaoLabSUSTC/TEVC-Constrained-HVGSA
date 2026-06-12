classdef CBOP3 < PROBLEM
% <multi> <real> <large/none> <expensive/none>
% Benchmark MOP proposed by Zitzler, Deb, and Thiele

%------------------------------- Reference --------------------------------
% E. Zitzler, K. Deb, and L. Thiele, Comparison of multiobjective
% evolutionary algorithms: Empirical results, Evolutionary computation,
% 2000, 8(2): 173-195.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2024 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    methods
        %% Default settings of the problem
        function Setting(obj)
            obj.M = 2;
            if isempty(obj.D); obj.D = 2; end
            obj.lower    = [-50, -50];
            obj.upper    = [50, 50];
            obj.encoding = ones(1,obj.D);
            obj.parameter.gn = 1;
            obj.parameter.hn = 1;            
        end
        %% Calculate objective values
        function Population = Evaluation(obj,varargin)
            PopDec  = varargin{1};
            PopDec  = max(min(PopDec,repmat(obj.upper,size(PopDec,1),1)),repmat(obj.lower,size(PopDec,1),1));
            PopObj(:,1) = PopDec(:,1).^2 + PopDec(:,2).^2;
            PopObj(:,2) = (PopDec(:,1)-10).^2 + PopDec(:,2).^2;
            PopCon(:,1) = - PopDec(:, 2) + 1;
            PopCon(:,2) = abs(- PopDec(:, 2) + 2);
            Population  = SOLUTION(PopDec,PopObj,PopCon,varargin{2:end});
            obj.FE      = obj.FE + length(Population);
        end
        %% Generate points on the Pareto front
        function R = GetOptimum(obj,N)
            R(:,1) = linspace(0,1,N)';
            R(:,2) = 1 - R(:,1).^0.5;
        end
        %% Generate the image of Pareto front
        function R = GetPF(obj)
            R = obj.GetOptimum(100);
        end
    end
end