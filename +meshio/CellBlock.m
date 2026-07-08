classdef CellBlock
    % CELLBLOCK  A block of cells of a single type.
    %   Mirrors meshio._mesh.CellBlock.
    %
    %   Properties
    %     type  - cell-type name, e.g. "triangle" (string scalar)
    %     data  - connectivity: numeric matrix [nCells x nNodesPerCell], or
    %             a cell array of row vectors for polyhedron types
    %     dim   - topological dimension
    %     tags  - optional tag strings (string array)

    properties
        type    (1,1) string
        data
        dim     (1,1) double
        tags    (1,:) string = string.empty(1,0)
    end

    methods
        function obj = CellBlock(cell_type, data, tags)
            if nargin == 0
                return
            end
            obj.type = string(cell_type);
            obj.data = data;
            if startsWith(obj.type, "polyhedron")
                obj.dim = 3;
            else
                td = meshio.internal.topological_dimension();
                obj.dim = td(obj.type);
            end
            if nargin >= 3 && ~isempty(tags)
                obj.tags = string(tags);
            end
        end

        function n = len(obj)
            % LEN  Number of cells in this block (mirrors Python __len__).
            if iscell(obj.data)
                n = numel(obj.data);
            else
                n = size(obj.data, 1);
            end
        end

        function disp(obj)
            if ~isscalar(obj)
                sz = strjoin(string(size(obj)), "x");
                fprintf("  %s meshio.CellBlock array:\n", sz);
                for i = 1:numel(obj)
                    fprintf("    (%d) type: %s, num cells: %d, tags: [%s]\n", ...
                        i, obj(i).type, obj(i).len(), strjoin(obj(i).tags, ", "));
                end
                return
            end
            items = sprintf("type: %s, num cells: %d, tags: [%s]", ...
                obj.type, obj.len(), strjoin(obj.tags, ", "));
            fprintf("<meshio CellBlock, %s>\n", items);
        end
    end
end
