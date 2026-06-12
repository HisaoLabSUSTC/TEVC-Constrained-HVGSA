PROBLEM = @Example1Problem;
algorithm = {@Example1Algorithm};

FE = 10;

platemo('problem', PROBLEM, 'N', 100,  ...
        'maxFE', FE, 'algorithm', algorithm{:});