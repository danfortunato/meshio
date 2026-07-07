classdef Mesh < handle & matlab.mixin.Copyable
    % MESH  Unstructured mesh container.
    %   Mirrors meshio._mesh.Mesh. Handle class so methods like
    %   cell_sets_to_data mutate in place (matches Python semantics).
    %
    %   Properties
    %     points         - [nPoints x dim] coordinates
    %     cells          - row array of meshio.CellBlock
    %     point_data     - dictionary string -> array (nPoints x ...)
    %     cell_data      - dictionary string -> cell array of arrays
    %                      (one per cell block)
    %     field_data     - dictionary (free-form)
    %     point_sets     - dictionary string -> point-index array
    %     cell_sets      - dictionary string -> cell array of index arrays
    %     gmsh_periodic  - opaque (gmsh-specific)
    %     info           - opaque

    properties
        points
        cells = meshio.CellBlock.empty(1,0)
        point_data    (1,1) dictionary
        cell_data     (1,1) dictionary
        field_data    (1,1) dictionary
        point_sets    (1,1) dictionary
        cell_sets     (1,1) dictionary
        gmsh_periodic
        info
    end

    properties (Dependent, SetAccess = private)
        cells_dict
        cell_data_dict
        cell_sets_dict
    end

    methods
        function obj = Mesh(points, cells, options)
            arguments
                points
                cells
                options.point_data    = []
                options.cell_data     = []
                options.field_data    = []
                options.point_sets    = []
                options.cell_sets     = []
                options.gmsh_periodic = []
                options.info          = []
            end

            obj.points = points;
            obj.cells  = meshio.Mesh.parse_cells(cells);

            obj.point_data    = meshio.Mesh.as_dict(options.point_data);
            obj.cell_data     = meshio.Mesh.as_dict(options.cell_data);
            obj.field_data    = meshio.Mesh.as_dict(options.field_data);
            obj.point_sets    = meshio.Mesh.as_dict(options.point_sets);
            obj.cell_sets     = meshio.Mesh.as_dict(options.cell_sets);
            obj.gmsh_periodic = options.gmsh_periodic;
            obj.info          = options.info;

            % point_data consistency
            pkeys = keys(obj.point_data);
            for i = 1:numel(pkeys)
                key = pkeys(i);
                val = obj.point_data{key};
                if size(val, 1) ~= size(obj.points, 1)
                    error("meshio:Mesh:pointDataLength", ...
                        "size(points,1) = %d, but size(point_data(""%s""),1) = %d", ...
                        size(obj.points,1), key, size(val,1));
                end
            end

            % cell_data consistency
            ckeys = keys(obj.cell_data);
            nblocks = numel(obj.cells);
            for i = 1:numel(ckeys)
                key  = ckeys(i);
                data = obj.cell_data{key};
                if numel(data) ~= nblocks
                    error("meshio:Mesh:cellDataBlocks", ...
                        "Incompatible cell data '%s'. %d cell blocks, but '%s' has %d.", ...
                        key, nblocks, key, numel(data));
                end
                for k = 1:nblocks
                    if size(data{k}, 1) ~= obj.cells(k).len()
                        error("meshio:Mesh:cellDataLength", ...
                            "Incompatible cell data. Block %d ('%s') has length %d, but corresponding cell data has length %d.", ...
                            k, obj.cells(k).type, obj.cells(k).len(), size(data{k},1));
                    end
                end
            end
        end

        function disp(obj)
            lines = strings(0);
            lines(end+1) = "<meshio mesh object>";
            lines(end+1) = sprintf("  Number of points: %d", size(obj.points,1));
            special = ["polygon", "polyhedron", ...
                "VTK_LAGRANGE_CURVE", "VTK_LAGRANGE_TRIANGLE", ...
                "VTK_LAGRANGE_QUADRILATERAL", "VTK_LAGRANGE_TETRAHEDRON", ...
                "VTK_LAGRANGE_HEXAHEDRON", "VTK_LAGRANGE_WEDGE", ...
                "VTK_LAGRANGE_PYRAMID"];
            if ~isempty(obj.cells)
                lines(end+1) = "  Number of cells:";
                for i = 1:numel(obj.cells)
                    cb = obj.cells(i);
                    s = cb.type;
                    if any(cb.type == special)
                        if ~iscell(cb.data)
                            s = sprintf("%s(%d)", s, size(cb.data, 2));
                        end
                    end
                    lines(end+1) = sprintf("    %s: %d", s, cb.len()); %#ok<AGROW>
                end
            else
                lines(end+1) = "  No cells.";
            end
            if numEntries(obj.point_sets) > 0
                lines(end+1) = "  Point sets: " + strjoin(keys(obj.point_sets), ", ");
            end
            if numEntries(obj.cell_sets) > 0
                lines(end+1) = "  Cell sets: " + strjoin(keys(obj.cell_sets), ", ");
            end
            if numEntries(obj.point_data) > 0
                lines(end+1) = "  Point data: " + strjoin(keys(obj.point_data), ", ");
            end
            if numEntries(obj.cell_data) > 0
                lines(end+1) = "  Cell data: " + strjoin(keys(obj.cell_data), ", ");
            end
            if numEntries(obj.field_data) > 0
                lines(end+1) = "  Field data: " + strjoin(keys(obj.field_data), ", ");
            end
            fprintf("%s\n", strjoin(lines, newline));
        end

        function write(obj, path_or_buf, file_format, varargin)
            % WRITE  Write this mesh to a file. Mirrors Mesh.write.
            if nargin < 3
                file_format = [];
            end
            meshio.write(path_or_buf, obj, file_format, varargin{:});
        end

        function out = get_cells_type(obj, cell_type)
            cell_type = string(cell_type);
            matches = false(1, numel(obj.cells));
            for i = 1:numel(obj.cells)
                matches(i) = obj.cells(i).type == cell_type;
            end
            if ~any(matches)
                nnpc = meshio.internal.num_nodes_per_cell();
                out = zeros(0, nnpc(cell_type));
                return
            end
            blocks = obj.cells(matches);
            parts = cell(1, numel(blocks));
            for i = 1:numel(blocks)
                parts{i} = blocks(i).data;
            end
            out = vertcat(parts{:});
        end

        function out = get_cell_data(obj, name, cell_type)
            cell_type = string(cell_type);
            data = obj.cell_data{name};
            parts = {};
            for i = 1:numel(obj.cells)
                if obj.cells(i).type == cell_type
                    parts{end+1} = data{i}; %#ok<AGROW>
                end
            end
            out = vertcat(parts{:});
        end

        function d = get.cells_dict(obj)
            d = configureDictionary("string", "cell");
            for i = 1:numel(obj.cells)
                cb = obj.cells(i);
                if isKey(d, cb.type)
                    d{cb.type} = [d{cb.type}; cb.data];
                else
                    d{cb.type} = cb.data;
                end
            end
        end

        function d = get.cell_data_dict(obj)
            d = configureDictionary("string", "cell");
            dkeys = keys(obj.cell_data);
            for i = 1:numel(dkeys)
                key = dkeys(i);
                vals = obj.cell_data{key};
                per_type = configureDictionary("string", "cell");
                for k = 1:numel(obj.cells)
                    t = obj.cells(k).type;
                    if isKey(per_type, t)
                        per_type{t} = [per_type{t}; vals{k}];
                    else
                        per_type{t} = vals{k};
                    end
                end
                d{key} = per_type;
            end
        end

        function d = get.cell_sets_dict(obj)
            d = configureDictionary("string", "cell");
            skeys = keys(obj.cell_sets);
            for i = 1:numel(skeys)
                key = skeys(i);
                member_list = obj.cell_sets{key};
                per_type = configureDictionary("string", "cell");
                offsets  = configureDictionary("string", "double");
                for k = 1:numel(obj.cells)
                    cb = obj.cells(k);
                    members = member_list{k};
                    if isempty(members)
                        continue
                    end
                    t = cb.type;
                    if isKey(offsets, t)
                        offset = offsets(t);
                        offsets(t) = offsets(t) + size(cb.data, 1);
                    else
                        offset = 0;
                        offsets(t) = size(cb.data, 1);
                    end
                    shifted = members + offset;
                    if isKey(per_type, t)
                        per_type{t} = [per_type{t}; shifted(:)];
                    else
                        per_type{t} = shifted(:);
                    end
                end
                inner_keys = keys(per_type);
                for j = 1:numel(inner_keys)
                    if isempty(per_type{inner_keys(j)})
                        remove(per_type, inner_keys(j));
                    end
                end
                d{key} = per_type;
            end
        end

        function cell_sets_to_data(obj, data_name)
            arguments
                obj
                data_name = ""
            end
            default_value = -1;
            if numEntries(obj.cell_sets) == 0
                return
            end
            skeys = keys(obj.cell_sets);
            nblocks = numel(obj.cells);
            intfun = cell(1, nblocks);
            for k = 1:nblocks
                arr = repmat(int32(default_value), obj.cells(k).len(), 1);
                for i = 1:numel(skeys)
                    members = obj.cell_sets{skeys(i)}{k};
                    if isempty(members)
                        continue
                    end
                    arr(members) = int32(i - 1);
                end
                intfun{k} = arr;
            end
            for k = 1:nblocks
                ndef = sum(intfun{k} == default_value);
                if ndef > 0
                    warning("meshio:cellSetDefault", ...
                        "%d cells are not part of any cell set. Using default value %d.", ...
                        ndef, default_value);
                    break
                end
            end
            if data_name == ""
                data_name = strjoin(skeys, "-");
            end
            obj.cell_data{data_name} = intfun;
            obj.cell_sets = configureDictionary("string", "cell");
        end

        function point_sets_to_data(obj, join_char)
            arguments
                obj
                join_char (1,1) string = "-"
            end
            default_value = -1;
            if numEntries(obj.point_sets) == 0
                return
            end
            intfun = repmat(int32(default_value), size(obj.points,1), 1);
            skeys = keys(obj.point_sets);
            for i = 1:numel(skeys)
                cc = obj.point_sets{skeys(i)};
                intfun(cc) = int32(i - 1);
            end
            if any(intfun == default_value)
                warning("meshio:pointSetDefault", ...
                    "Not all points are part of a point set. Using default value %d.", ...
                    default_value);
            end
            data_name = strjoin(skeys, join_char);
            obj.point_data{data_name} = intfun;
            obj.point_sets = configureDictionary("string", "cell");
        end

        function cell_data_to_sets(obj, key)
            data = obj.cell_data{key};
            for i = 1:numel(data)
                if ~isinteger(data{i})
                    error("meshio:notIntData", "cell_data('%s') is not int data.", key);
                end
            end
            tags = unique(vertcat(data{:}));
            names = unique(split(key, "-"), "stable");
            if numel(names) ~= numel(tags)
                names = arrayfun(@(t) sprintf("set-%s-%d", key, t), tags, ...
                    "UniformOutput", false);
                names = string(names);
            end
            for n = 1:numel(names)
                tag = tags(n);
                members = cell(1, numel(data));
                for i = 1:numel(data)
                    members{i} = find(data{i} == tag);
                end
                obj.cell_sets{names(n)} = members;
            end
            remove(obj.cell_data, key);
        end

        function point_data_to_sets(obj, key)
            data = obj.point_data{key};
            if ~isinteger(data)
                error("meshio:notIntData", "point_data('%s') is not int data.", key);
            end
            tags = unique(data);
            names = unique(split(key, "-"), "stable");
            if numel(names) ~= numel(tags)
                names = arrayfun(@(t) sprintf("set-key-%d", t), tags, ...
                    "UniformOutput", false);
                names = string(names);
            end
            for n = 1:numel(names)
                obj.point_sets{names(n)} = find(data == tags(n));
            end
            remove(obj.point_data, key);
        end
    end

    methods (Static)
        function mesh = read(path_or_buf, file_format)
            % Deprecated: use meshio.read instead. Mirrors Mesh.read.
            arguments
                path_or_buf
                file_format = []
            end
            warning("meshio:deprecatedRead", ...
                "meshio.Mesh.read is deprecated, use meshio.read instead");
            mesh = meshio.read(path_or_buf, file_format);
        end

        function blocks = parse_cells(cells)
            if isa(cells, "meshio.CellBlock")
                blocks = reshape(cells, 1, []);
                return
            end
            if isa(cells, "dictionary")
                % old dict, deprecated -- convert dict to list of tuples
                ks = keys(cells);
                blocks = meshio.CellBlock.empty(1,0);
                for i = 1:numel(ks)
                    blocks(end+1) = meshio.CellBlock(ks(i), cells{ks(i)}); %#ok<AGROW>
                end
                return
            end
            blocks = meshio.CellBlock.empty(1, 0);
            for i = 1:numel(cells)
                item = cells{i};
                if isa(item, "meshio.CellBlock")
                    blocks(end+1) = item; %#ok<AGROW>
                else
                    blocks(end+1) = meshio.CellBlock(item{1}, item{2}); %#ok<AGROW>
                end
            end
        end

        function d = as_dict(x)
            if isempty(x)
                d = configureDictionary("string", "cell");
            else
                d = x;
            end
        end
    end
end
