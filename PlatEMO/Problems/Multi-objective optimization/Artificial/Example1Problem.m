classdef Example1Problem < PROBLEM
    methods
        %% Default settings of the problem
        function Setting(obj)
            obj.M = 2;
            if isempty(obj.D); obj.D = 2; end
            obj.lower    = [-100, -100];
            obj.upper    = [100, 100];
            obj.encoding = ones(1,obj.D);
            obj.parameter.gn = 0;
            obj.parameter.hn = 0;
        end
        %% Calculate objective values
        function Population = Evaluation(obj,varargin)
            PopDec  = varargin{1};
            PopDec  = max(min(PopDec,repmat(obj.upper,size(PopDec,1),1)),repmat(obj.lower,size(PopDec,1),1));
            PopObj(:,1) = PopDec(:,1).^2 + PopDec(:,2).^2;
            PopObj(:,2) = (PopDec(:,1)-10).^2 + PopDec(:,2).^2;
            PopCon = 1-PopDec(:,2);
            Population  = SOLUTION(PopDec,PopObj,PopCon,varargin{2:end});
            obj.FE      = obj.FE + length(Population);
        end
        %% Generate points on the Pareto front
        function R = GetOptimum(obj,N)
            dec_1 = linspace(0, 10, N)';
            dec_2 = ones(N, 1);
            R(:,1) = dec_1.^2 + dec_2.^2;
            R(:,2) = (dec_1-10).^2 + dec_2.^2;
        end
        %% Generate points  on the Pareto set
        function R = GetPS(obj,N)
            R(:,1) = linspace(0, 10, N)';
            R(:,2) = 1;
        end
        %% Generate the image of Pareto front
        function R = GetPF(obj)
            R = obj.GetOptimum(100);
        end
    end
end