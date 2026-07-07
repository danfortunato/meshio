function mesh = read(filename)
% READ  Read an OFF surface mesh. Mirrors meshio.off._off.read.
%   OFF format spec: <http://www.geomview.org/docs/html/OFF.html>
%   Indices on file are 0-based; converted to 1-based here.
    fid = fopen(filename, 'r');
    if fid < 0
        error("meshio:ReadError", "Cannot open '%s'.", filename);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    line = strtrim(string(fgetl(fid)));
    if line ~= "OFF"
        error("meshio:ReadError", "Expected first line to be `OFF`, got '%s'.", line);
    end

    while true
        raw = fgetl(fid);
        if ~ischar(raw)
            error("meshio:ReadError", "Unexpected EOF before counts.");
        end
        line = strtrim(string(raw));
        if line ~= "" && extractBefore(line + " ", 2) ~= "#"
            break
        end
    end

    counts = sscanf(line, "%d %d %d");
    if numel(counts) < 2
        error("meshio:ReadError", "Bad counts line: '%s'.", line);
    end
    num_verts = counts(1);
    num_faces = counts(2);

    verts = fscanf(fid, "%f", [3, num_verts])';
    data  = fscanf(fid, "%d", [4, num_faces])';

    if ~all(data(:,1) == 3)
        error("meshio:ReadError", "Can only read triangular faces.");
    end

    tri = data(:, 2:4) + 1;  % 0-based -> 1-based
    cells = meshio.CellBlock("triangle", tri);
    mesh  = meshio.Mesh(verts, cells);
end
