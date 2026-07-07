function write(filename, mesh)
% WRITE  Write a Wavefront OBJ file. Mirrors meshio.obj._obj.write.
%   OBJ indices are 1-based on file -- same as MATLAB.
    for i = 1:numel(mesh.cells)
        t = mesh.cells(i).type;
        if ~ismember(t, ["triangle", "quad", "polygon"])
            error("meshio:WriteError", ...
                "Wavefront .obj files can only contain triangle, quad, or polygon cells (got '%s').", t);
        end
    end

    fid = fopen(filename, 'w');
    if fid < 0
        error("meshio:WriteError", "Cannot open '%s' for writing.", filename);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    ts = char(datetime("now", "Format", "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"));
    fprintf(fid, "# Created by meshio (matlab port), %s\n", ts);

    fprintf(fid, "v %.17g %.17g %.17g\n", mesh.points');

    if isKey(mesh.point_data, "obj:vn")
        dat = mesh.point_data{"obj:vn"};
        fmt = ['vn', repmat(' %.17g', 1, size(dat, 2)), '\n'];
        fprintf(fid, fmt, dat');
    end

    if isKey(mesh.point_data, "obj:vt")
        dat = mesh.point_data{"obj:vt"};
        fmt = ['vt', repmat(' %.17g', 1, size(dat, 2)), '\n'];
        fprintf(fid, fmt, dat');
    end

    for k = 1:numel(mesh.cells)
        cb = mesh.cells(k);
        fmt = ['f', repmat(' %d', 1, size(cb.data, 2)), '\n'];
        fprintf(fid, fmt, cb.data');
    end
end
