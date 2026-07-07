function write(filename, mesh)
% WRITE  Write an OFF surface mesh. Mirrors meshio.off._off.write.
%   Only triangle cells are written; other cell types are skipped with a warning.
%   Indices in the file are 0-based (converted from MATLAB 1-based).
    points = mesh.points;
    if size(points, 2) == 2
        warning("meshio:off:pad2D", ...
            "OFF requires 3D points, but 2D points given. Appending zero z-coordinate.");
        points = [points, zeros(size(points,1), 1)];
    end

    skip_idx = false(1, numel(mesh.cells));
    for i = 1:numel(mesh.cells)
        skip_idx(i) = mesh.cells(i).type ~= "triangle";
    end
    if any(skip_idx)
        skipped = strjoin([mesh.cells(skip_idx).type], ", ");
        warning("meshio:off:skipNonTriangle", ...
            "OFF only supports triangle cells. Skipping: %s.", skipped);
    end

    tri = mesh.get_cells_type("triangle");

    fid = fopen(filename, 'w');
    if fid < 0
        error("meshio:WriteError", "Cannot open '%s' for writing.", filename);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, "OFF\n");
    fprintf(fid, "# Created by meshio\n\n");
    fprintf(fid, "%d %d %d\n\n", size(points,1), size(tri,1), 0);

    fprintf(fid, "%.17g %.17g %.17g\n", points');

    % triangles: prepend 3, convert to 0-based
    out = [3 * ones(size(tri,1), 1), tri - 1];
    fprintf(fid, "%d %d %d %d\n", out');
end
