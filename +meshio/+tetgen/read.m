function mesh = read(filename)
% READ  I/O for the TetGen file format, c.f.
%   <https://wias-berlin.de/software/tetgen/fformats.node.html>
    [base, ext] = split_ext(filename);
    if ext == ".node"
        node_filename = filename;
        ele_filename  = base + ".ele";
    elseif ext == ".ele"
        node_filename = base + ".node";
        ele_filename  = filename;
    else
        error("meshio:ReadError", ...
            "TetGen filename must end in .node or .ele (got %s).", filename);
    end

    point_data = configureDictionary("string", "cell");
    cell_data  = configureDictionary("string", "cell");

    % read nodes
    [points, node_index_base, point_data] = ...
        read_nodes(node_filename, point_data);

    % read elements
    [cells, cell_data] = read_elements(ele_filename, node_index_base, cell_data);

    mesh = meshio.Mesh(points, cells, ...
        point_data = point_data, cell_data = cell_data);
end


function [points, node_index_base, point_data] = read_nodes(filename, point_data)
    fid = fopen(filename, 'r');
    if fid < 0
        error("meshio:ReadError", "Cannot open '%s'.", filename);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    line = read_significant_line(fid);
    parts = sscanf(line, '%d');
    num_points = parts(1);
    dim        = parts(2);
    num_attrs  = parts(3);
    num_bmarkers = parts(4);
    if dim ~= 3
        error("meshio:ReadError", "Need 3D points.");
    end

    ncols = 4 + num_attrs + num_bmarkers;
    raw = fscanf(fid, '%f', [ncols, num_points])';

    node_index_base = raw(1, 1);
    % make sure the nodes are numbered consecutively
    expected = (node_index_base : node_index_base + size(raw, 1) - 1)';
    if ~isequal(raw(:, 1), expected)
        error("meshio:ReadError", "TetGen node indices not consecutive.");
    end

    % read point attributes
    for k = 1:num_attrs
        point_data{"tetgen:attr" + k} = raw(:, 4 + k);
    end
    % read boundary markers, the first is "ref", the others are "ref2", "ref3", ...
    for k = 1:num_bmarkers
        if k == 1, flag = ""; else, flag = string(k); end
        point_data{"tetgen:ref" + flag} = raw(:, 4 + num_attrs + k);
    end
    % remove the leading index column, the attributes, and the boundary markers
    points = raw(:, 2:4);
end


function [cells, cell_data] = read_elements(filename, node_index_base, cell_data)
    fid = fopen(filename, 'r');
    if fid < 0
        error("meshio:ReadError", "Cannot open '%s'.", filename);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    line = read_significant_line(fid);
    parts = sscanf(line, '%d');
    num_tets = parts(1);
    num_points_per_tet = parts(2);
    num_attrs = parts(3);
    if num_points_per_tet ~= 4
        error("meshio:ReadError", "TetGen: need 4 nodes per tetra (got %d).", num_points_per_tet);
    end

    ncols = 5 + num_attrs;
    raw = fscanf(fid, '%d', [ncols, num_tets])';

    % read cell (region) attributes, the first is "ref", the others are "ref2", "ref3", ...
    for k = 1:num_attrs
        if k == 1, flag = ""; else, flag = string(k); end
        cell_data{"tetgen:ref" + flag} = {raw(:, 5 + k)};
    end
    % remove the leading index column and the attributes
    tetra = raw(:, 2:5);
    % convert from file indexing to MATLAB 1-based
    tetra = tetra - node_index_base + 1;
    cells = meshio.CellBlock("tetra", tetra);
end


function line = read_significant_line(fid)
    while true
        raw = fgetl(fid);
        if ~ischar(raw)
            error("meshio:ReadError", "Unexpected EOF in TetGen header.");
        end
        line = strtrim(raw);
        if ~isempty(line) && line(1) ~= '#'
            return
        end
    end
end


function [base, ext] = split_ext(filename)
    filename = string(filename);
    [d, n, e] = fileparts(filename);
    base = fullfile(d, n);
    ext = lower(string(e));
end
