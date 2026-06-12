classdef EqCo3 < PROBLEM
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
            if isempty(obj.D); obj.D = 2; end
            obj.lower    = -11*ones(1,obj.D);
            obj.upper    = 11*ones(1,obj.D);
            obj.encoding = ones(1,obj.D);
            obj.POS = [];
        end
        %% Calculate objective values
        function PopObj = CalObj(obj,PopDec)
            x = PopDec;
            num_decs = size(x,2);

            a1 = [0,-10];
            a2 = [10,0];
        
%             f1 = sum((x(:,2:end)-a1(2:end)).^2,2);
%             f1(:) = f1(:) + (x(:,1)-a1(1)).^4;
%             f2 = (x(:,1)-a2(1)).^2 + sum((x(:,3:end)-a2(3:end)).^2,2);
%             f2(:) = f2(:) + (x(:,2)-a2(2)).^4;
            f1 = sum((x-a1).^2,2);
            f2 = sum((x-a2).^2,2);

            PopObj(:,1) = f1;
            PopObj(:,2) = f2;
        end
        %% Constraint Function (for equality constraints)
        function PopCon = CalCon(obj, PopDec)
            x = PopDec;
            % First equality constraint:
            r = 1;
            c = zeros(1,size(x,2));
%             PopCon = abs( vecnorm(x-c,2,2).^2-r );
            PopCon = vecnorm(x-c,2,2).^2-r ;
        end
        %% Generate points on the Pareto front
        function R = GetOptimum(obj,N)
            R = [];
        end
        %% Generate the image of Pareto front
        function R = GetPF(obj)
            R = [];
        end
    end
end