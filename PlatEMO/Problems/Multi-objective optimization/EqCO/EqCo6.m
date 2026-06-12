classdef EqCo6 < PROBLEM
% <multi> <real> <large/none> <expensive/none>
% NPQe problems
% Constrained Problem 2_1
    properties
        POS;
    end
    methods
        %% Default settings of the problem
        function Setting(obj)
            obj.M = 2;
            if isempty(obj.D); obj.D = 5; end
            obj.lower    = 0*ones(1,obj.D);
            obj.upper    = 1*ones(1,obj.D);
            obj.encoding = ones(1,obj.D);
            obj.POS = [];
        end
        %% Calculate objective values
        function PopObj = CalObj(obj,PopDec)
            x = PopDec;
            num_decs = size(x,2);

            
            f1 = x(:,1);
            f2 = x(:,2);

            PopObj(:,1) = f1;
            PopObj(:,2) = f2;
        end
        %% Constraint Function (for equality constraints)
        function PopCon = CalCon(obj, PopDec)
            x = PopDec;
            PopCon = -x(:,2)+1-x(:,1).^2;

            % PopCon = [ vecnorm(x-c,2,2).^2-r, -1*(vecnorm(x-c,2,2).^2-r)];
        end
        %% Generate points on the Pareto front
        function R = GetOptimum(obj,N)
            R = ones(N, obj.M);
        end
        %% Generate the image of Pareto front
        function R = GetPF(obj)
            R = obj.GetOptimum(100);
        end
    end
end