classdef DASCMaOP1 < PROBLEM
% <many> <real> <large/none> <constrained>
% Difficulty-adjustable and scalable constrained many-objective problem 1
% Uses WFG1 objectives with the DAS constraint toolkit (Eq. 8 in Fan et al.)

%------------------------------- Reference --------------------------------
% Z. Fan, W. Li, X. Cai, H. Li, C. Wei, Q. Zhang, K. Deb, and E. Goodman,
% Difficulty adjustable and scalable constrained multi-objective test
% problem toolkit, Evolutionary Computation, 2020, 28(3): 339-378.
%------------------------------- Copyright --------------------------------
% DASCMaOP1 = WFG1 objectives + DAS constraints (eta, zeta, gamma)

% K       ---     --- Position parameter (must be a multiple of M-1)
% triplet --- [0,0.5,0.5] --- Difficulty triplet (eta, zeta, gamma)

    properties(Access = private)
        K;       % Number of position-related parameters
        triplet; % Difficulty triplet [eta, zeta, gamma]
    end
    methods
        %% Default settings of the problem
        function Setting(obj)
            if isempty(obj.M); obj.M = 5; end
            % K defaults to 2*(M-1) to be divisible by M-1; l=20 distance params
            [obj.K,obj.triplet] = obj.ParameterSet(2*(obj.M-1),[0.25,0.25,0.25]);
            if isempty(obj.D); obj.D = obj.K + 20; end
            obj.lower    = zeros(1,obj.D);
            obj.upper    = 2:2:2*obj.D;
            obj.encoding = ones(1,obj.D);
            obj.parameter.gn = 2*obj.M + 1;
            obj.parameter.hn = 0;
        end
        %% Calculate objective values
        function PopObj = CalObj(obj,PopDec)
            [PopObj,~] = EvalWFG1(PopDec,obj.M,obj.K);
        end
        %% Calculate constraint violations
        function PopCon = CalCon(obj,PopDec)
            [PopObj,x] = EvalWFG1(PopDec,obj.M,obj.K);
            M = obj.M;
            S = 2:2:2*M;
            N = size(PopDec,1);
            PopCon = DASCMaOPConstraint(x,PopObj,S,M,N,obj.triplet);
        end
        %% Generate points on the Pareto front
        function R = GetOptimum(obj,N)
            % Returns the unconstrained WFG1 PF (same approach as PlatEMO WFG1)
            % For the true constrained PF, constraint filtering is needed
            M = obj.M;
            R = UniformPoint(N,M);
            c = ones(size(R,1),M);
            for i = 1:size(R,1)
                for j = 2:M
                    temp = R(i,j)/R(i,1)*prod(1-c(i,M-j+2:M-1));
                    c(i,M-j+1) = (temp^2-temp+sqrt(2*temp))/(temp^2+1);
                end
            end
            x = acos(c)*2/pi;
            temp = (1-sin(pi/2*x(:,2))).*R(:,M)./R(:,M-1);
            a = 0:0.0001:1;
            E = abs(temp*(1-cos(pi/2*a))-1+repmat(a+cos(10*pi*a+pi/2)/10/pi,size(x,1),1));
            [~,rank] = sort(E,2);
            for i = 1:size(x,1)
                x(i,1) = a(min(rank(i,1:10)));
            end
            R      = convex(x);
            R(:,M) = mixed(x);
            R      = repmat(2:2:2*M,size(R,1),1).*R;
        end
        %% Generate the image of Pareto front
        function R = GetPF(obj)
            if obj.M == 2
                R = obj.GetOptimum(100);
            elseif obj.M == 3
                a = linspace(0,pi/2,10)';
                x = (1-cos(a))*(1-cos(a'));
                y = (1-cos(a))*(1-sin(a'));
                z = 1 - a*ones(size(a'))*2/pi - cos(20*a*ones(size(a'))+pi/2)/10/pi;
                R = {x*2,y*4,z*6};
            else
                R = [];
            end
        end
    end
end

%% =========== WFG1 Objective Evaluation ===========
% Returns both objectives and the intermediate x vector (needed for constraints)
function [PopObj,x] = EvalWFG1(PopDec,M,K)
    [N,D] = size(PopDec);
    L = D - K;
    S = 2:2:2*M;
    A = ones(1,M-1);

    z01 = PopDec ./ repmat(2:2:D*2,N,1);

    % Transition 1: linear shift on distance parameters
    t1        = zeros(N,K+L);
    t1(:,1:K) = z01(:,1:K);
    t1(:,K+1:end) = s_linear(z01(:,K+1:end),0.35);

    % Transition 2: flat region bias on distance parameters
    t2        = zeros(N,K+L);
    t2(:,1:K) = t1(:,1:K);
    t2(:,K+1:end) = b_flat(t1(:,K+1:end),0.8,0.75,0.85);

    % Transition 3: polynomial bias on all parameters
    t3 = b_poly(t2,0.02);

    % Transition 4: weighted sum reduction to M parameters
    t4 = zeros(N,M);
    for i = 1:M-1
        t4(:,i) = r_sum(t3(:,(i-1)*K/(M-1)+1:i*K/(M-1)), ...
            2*((i-1)*K/(M-1)+1):2:2*i*K/(M-1));
    end
    t4(:,M) = r_sum(t3(:,K+1:K+L),2*(K+1):2:2*(K+L));

    % Compute underlying parameters x from t4
    x = zeros(N,M);
    for i = 1:M-1
        x(:,i) = max(t4(:,M),A(i)).*(t4(:,i)-0.5)+0.5;
    end
    x(:,M) = t4(:,M);

    % WFG1 shape functions: convex for f1..fM-1, mixed for fM
    h      = convex(x);
    h(:,M) = mixed(x);
    PopObj = repmat(x(:,M),1,M) + repmat(S,N,1).*h;
end

%% =========== DAS-CMaOP Constraint Function (Eq. 8) ===========
% Shared by all DAS-CMaOP problems. Operates on:
%   x      - M-dimensional intermediate WFG vector (N x M)
%   PopObj - objective values (N x M)
%   S      - scaling constants [2, 4, ..., 2M]
%   M      - number of objectives
%   N      - population size
%   triplet- [eta, zeta, gamma] difficulty factors in [0,1]
function PopCon = DASCMaOPConstraint(x,PopObj,S,M,N,triplet)
    eta   = triplet(1);  % diversity-hardness
    zeta  = triplet(2);  % feasibility-hardness
    gamma = triplet(3);  % convergence-hardness

    a_const = 20;
    d_const = 0.5;

    % Total constraints: (M-1) Type-I + 1 Type-II + (M+1) Type-III = 2M+1
    PopCon = zeros(N,2*M+1);

    % --- Type-I constraints: diversity-hardness on x_{1:M-1} ---
    % c_k(x) = sin(a*pi*x_k) - b >= 0  (k odd)
    % c_k(x) = cos(a*pi*x_k) - b >= 0  (k even)
    % Violation form: PopCon = b - sin/cos(...)
    if eta ~= 0
        b = eta;
        for k = 1:M-1
            if mod(k,2) == 1
                PopCon(:,k) = b - sin(a_const * pi * x(:,k));
            else
                PopCon(:,k) = b - cos(a_const * pi * x(:,k));
            end
        end
    end
    % When eta==0, PopCon(:,1:M-1) stays 0 (feasible)

    % --- Type-II constraint: feasibility-hardness on x_M ---
    % c_M(x) = (e - x_M)*(x_M - d) >= 0
    % Violation form: PopCon = -(e - x_M)*(x_M - d)
    if zeta ~= 0
        e_val = d_const + 10^(-2*zeta);
        PopCon(:,M) = -(e_val - x(:,M)) .* (x(:,M) - d_const);
    end
    % When zeta==0, PopCon(:,M) stays 0 (feasible)

    % --- Type-III constraints: convergence-hardness on objectives ---
    % Sphere constraints in normalized objective space (f_j / S_j)
    if gamma ~= 0
        r = 0.5 * gamma;
        fNorm = PopObj ./ repmat(S,N,1);

        % M constraints: spheres centered at each unit vector e_P
        % c_{M+P} = sum_{j!=P}(f_j/S_j)^2 + (f_P/S_P - 1)^2 - r^2 >= 0
        % Violation: PopCon = r^2 - [sum]
        for P = 1:M
            sumVal = sum(fNorm.^2,2) - fNorm(:,P).^2 + (fNorm(:,P)-1).^2;
            PopCon(:,M+P) = r^2 - sumVal;
        end

        % 1 constraint: sphere centered at (1/sqrt(M), ..., 1/sqrt(M))
        % c_{2M+1} = sum_j (f_j/S_j - 1/sqrt(M))^2 - r^2 >= 0
        % Violation: PopCon = r^2 - sum
        sumVal = sum((fNorm - 1/sqrt(M)).^2,2);
        PopCon(:,2*M+1) = r^2 - sumVal;
    end
    % When gamma==0, PopCon(:,M+1:2M+1) stays 0 (feasible)
end

%% =========== WFG Transformation Helper Functions ===========
function Output = s_linear(y,A)
    Output = abs(y-A) ./ abs(floor(A-y)+A);
end

function Output = b_flat(y,A,B,C)
    Output = A+min(0,floor(y-B))*A.*(B-y)/B - min(0,floor(C-y))*(1-A).*(y-C)/(1-C);
    Output = round(Output*1e4)/1e4;
end

function Output = b_poly(y,a)
    Output = y.^a;
end

function Output = r_sum(y,w)
    Output = sum(y.*repmat(w,size(y,1),1),2) ./ sum(w);
end

%% =========== WFG Shape Functions ===========
function Output = convex(x)
    Output = fliplr(cumprod([ones(size(x,1),1),1-cos(x(:,1:end-1)*pi/2)],2)) .* ...
             [ones(size(x,1),1),1-sin(x(:,end-1:-1:1)*pi/2)];
end

function Output = mixed(x)
    Output = 1-x(:,1)-cos(10*pi*x(:,1)+pi/2)/10/pi;
end