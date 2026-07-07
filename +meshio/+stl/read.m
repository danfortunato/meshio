function mesh = read(filename)
% READ  Read an STL surface mesh. Mirrors meshio.stl._stl.read.
%   STL spec: <https://en.wikipedia.org/wiki/STL_(file_format)>.
%
%   Detects binary vs ASCII via file-size check (same heuristic as Python:
%   a binary STL of N triangles has size 84 + 50*N bytes).
    s = dir(filename);
    if isempty(s)
        error("meshio:ReadError", "File '%s' not found.", filename);
    end
    filesize_bytes = s.bytes;

    fid = fopen(filename, 'r', 'ieee-le');
    if fid < 0
        error("meshio:ReadError", "Cannot open '%s'.", filename);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    % Checking if the file is ASCII format is normally done by checking if
    % the first 5 characters of the header is "solid". Unfortunately there
    % are mesh files out there which are binary and still put "solid" there.
    % A suggested alternative is to pretend the file is binary, read the
    % num_triangles and see if it matches the file size.
    if filesize_bytes < 80
        mesh = read_ascii(fid);
        return
    end

    fseek(fid, 80, 'bof');
    num_triangles = double(fread(fid, 1, 'uint32=>uint32'));

    if 84 + num_triangles * 50 == filesize_bytes
        mesh = read_binary(fid, num_triangles);
        return
    end

    % Rewind and skip the header line
    fseek(fid, 0, 'bof');
    fgetl(fid);
    mesh = read_ascii(fid);
end


function mesh = read_ascii(fid)
    % Lines starting with these tokens are skipped; "facet normal x y z"
    % and "vertex x y z" lines contribute their last 3 tokens as floats.
    skip_starts = ["solid", "outer loop", "endloop", "endfacet", "endsolid"];
    rows = {};
    while true
        raw = fgetl(fid);
        if ~ischar(raw)
            break
        end
        line = strtrim(raw);
        if isempty(line)
            continue
        end
        if any(startsWith(line, skip_starts))
            continue
        end
        toks = regexp(line, '\s+', 'split');
        if numel(toks) < 3
            continue
        end
        rows{end+1} = str2double(toks(end-2:end)); %#ok<AGROW>
    end

    if isempty(rows)
        data = zeros(0, 3);
    else
        data = vertcat(rows{:});
    end

    if mod(size(data, 1), 4) ~= 0
        error("meshio:ReadError", "STL ASCII data shape not a multiple of 4.");
    end

    if isempty(data)
        points = zeros(0, 3);
        cells = meshio.CellBlock.empty(1, 0);
        cell_data = configureDictionary("string", "cell");
    else
        % Split off facet normals (rows 0, 4, 8, ... in 0-based -> 1, 5, 9, ...)
        facet_rows = false(size(data, 1), 1);
        facet_rows(1:4:end) = true;
        facet_normals = data(facet_rows, :);
        pts_data = data(~facet_rows, :);
        [points, cells] = data_from_facets(pts_data);
        cell_data = configureDictionary("string", "cell");
        cell_data{"facet_normals"} = {facet_normals};
    end

    mesh = meshio.Mesh(points, cells, cell_data=cell_data);
end


function mesh = read_binary(fid, num_triangles)
    % 50 bytes per triangle: 3 float32 normal + 9 float32 vertices + 1 uint16 attr count.
    raw = fread(fid, 50 * num_triangles, 'uint8=>uint8');
    raw = reshape(raw, 50, num_triangles);
    % Discard normals (1:12) and attr count (49:50); take vertex bytes (13:48).
    vertex_bytes = raw(13:48, :);
    facets = typecast(vertex_bytes(:), 'single');
    pts_data = double(reshape(facets, 3, 3 * num_triangles).');

    if num_triangles == 0
        points = zeros(0, 3);
        cells  = meshio.CellBlock.empty(1, 0);
    else
        [points, cells] = data_from_facets(pts_data);
    end
    mesh = meshio.Mesh(points, cells);
end


function [points, cells] = data_from_facets(pts_data)
    % Identify individual points and build the indexed connectivity array.
    if isempty(pts_data)
        points = zeros(0, 3);
        cells = meshio.CellBlock.empty(1, 0);
        return
    end
    [points, ~, ic] = unique(pts_data, "rows", "stable");
    tri = reshape(ic, 3, []).';
    cells = meshio.CellBlock("triangle", tri);
end
