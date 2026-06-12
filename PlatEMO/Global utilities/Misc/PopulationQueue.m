classdef PopulationQueue < handle
    properties (Access = private)
        data        % Cell array to store structs
        maxSize     % Maximum size of queue
        count       % Current number of elements
    end
    
    methods
        function obj = PopulationQueue(size)
            % Constructor - creates queue of specified size
            obj.maxSize = size;
            obj.data = cell(1, size);
            obj.count = 0;
        end
        
        function push(obj, popObject, iterValue)
            % Create new struct
            newStruct.pop = popObject;
            newStruct.iter = iterValue;
            
            % Shift existing elements to the right
            if obj.count > 0
                % Move elements one position to the right
                for i = min(obj.count, obj.maxSize-1):-1:1
                    obj.data{i+1} = obj.data{i};
                end
            end
            
            % Insert new element at front
            obj.data{1} = newStruct;
            
            % Update count (cap at maxSize)
            obj.count = min(obj.count + 1, obj.maxSize);
        end
        
        function element = get(obj, index)
            % Get element at specified index
            if index > 0 && index <= obj.count
                element = obj.data{index};
            else
                element = [];
            end
        end
        
        function displayQueue(obj)
            % Display current queue contents
            fprintf('Queue contents (front to back):\n');
            for i = 1:obj.count
                fprintf('Position %d: iter = %d\n', i, obj.data{i}.iter);
            end
        end

        function size = getSize(obj)
            size = obj.count;
        end

        function newObj = copy(obj)
            % Create a new PopulationQueue with the same maxSize
            newObj = PopulationQueue(obj.maxSize);

            % Copy data and count
            newObj.count = obj.count;

            % Deep copy each cell (structs)
            for i = 1:obj.count
                newObj.data{i} = obj.data{i};
            end
        end

    end
end