function write(filename, mesh, options)
% WRITE  Write a PLY mesh. Mirrors meshio.ply._ply.write.
%   PLY indices on file are 0-based (converted from MATLAB 1-based).
    arguments
        filename
        mesh           (1,1) meshio.Mesh
        options.binary (1,1) logical     = true
    end

    [~, ~, native_endian] = computer;
    endian_machine = lower(native_endian);   % 'l' or 'b'
    if native_endian == 'L', endian_word = "little"; else, endian_word = "big"; end

    if options.binary
        fid = fopen(filename, 'w', endian_machine);
    else
        fid = fopen(filename, 'w');
    end
    if fid < 0
        error("meshio:WriteError", "Cannot open '%s' for writing.", filename);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, "ply\n");
    if options.binary
        fprintf(fid, "format binary_%s_endian 1.0\n", endian_word);
    else
        fprintf(fid, "format ascii 1.0\n");
    end
    ts = char(datetime("now", "Format", "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"));
    fprintf(fid, "comment Created by meshio (matlab port), %s\n", ts);

    % --- header: vertex element ---
    npts = size(mesh.points, 1);
    fprintf(fid, "element vertex %d\n", npts);
    dim_names = ["x", "y", "z"];
    points_ply_type = matlab_to_ply_type(class(mesh.points));
    for d = 1:size(mesh.points, 2)
        fprintf(fid, "property %s %s\n", points_ply_type, dim_names(d));
    end

    pd_keys = keys(mesh.point_data);
    pd_values = {};
    pd_keys_used = strings(0);
    for i = 1:numel(pd_keys)
        v = mesh.point_data{pd_keys(i)};
        if ~isvector(v)
            warning("meshio:ply:multidim", ...
                "PLY writer doesn't support multidimensional point data yet. Skipping %s.", ...
                pd_keys(i));
            continue
        end
        v = v(:);
        t = matlab_to_ply_type(class(v));
        fprintf(fid, "property %s %s\n", t, pd_keys(i));
        pd_values{end+1} = v; %#ok<AGROW>
        pd_keys_used(end+1) = pd_keys(i); %#ok<AGROW>
    end

    % --- header: face element ---
    legal_types = ["vertex", "line", "triangle", "quad", "polygon"];
    num_cells = 0;
    for i = 1:numel(mesh.cells)
        if any(mesh.cells(i).type == legal_types)
            num_cells = num_cells + size(mesh.cells(i).data, 1);
        end
    end

    cell_dtype = "";
    if num_cells > 0
        fprintf(fid, "element face %d\n", num_cells);
        % cast int64/uint64 down to int32 (PLY doesn't support 64-bit ints)
        has_cast = false;
        for k = 1:numel(mesh.cells)
            if isa(mesh.cells(k).data, 'int64') || isa(mesh.cells(k).data, 'uint64')
                has_cast = true;
                mesh.cells(k) = meshio.CellBlock(mesh.cells(k).type, int32(mesh.cells(k).data));
            end
        end
        if has_cast
            warning("meshio:ply:cast64to32", ...
                "PLY doesn't support 64-bit integers. Casting down to 32-bit.");
        end
        % assert that all cell dtypes are equal
        for i = 1:numel(mesh.cells)
            if any(mesh.cells(i).type == legal_types)
                ct = string(class(mesh.cells(i).data));
                if cell_dtype == ""
                    cell_dtype = ct;
                elseif cell_dtype ~= ct
                    error("meshio:WriteError", "PLY: inconsistent cell data dtypes across blocks.");
                end
            end
        end
        if cell_dtype ~= ""
            ply_type = matlab_to_ply_type(cell_dtype);
            fprintf(fid, "property list uint8 %s vertex_indices\n", ply_type);
        end
    end

    fprintf(fid, "end_header\n");

    if options.binary
        write_binary_body(fid, mesh, pd_values, legal_types, cell_dtype);
    else
        write_ascii_body(fid, mesh, pd_values, legal_types);
    end
end


function write_ascii_body(fid, mesh, pd_values, legal_types)
    points = mesh.points;
    npts = size(points, 1);
    ncols_pts = size(points, 2);
    cols = cell(1, ncols_pts + numel(pd_values));
    for d = 1:ncols_pts
        cols{d} = double(points(:, d));
    end
    for i = 1:numel(pd_values)
        cols{ncols_pts + i} = double(pd_values{i});
    end
    if npts > 0
        fmt = [repmat('%.17g ', 1, numel(cols) - 1), '%.17g\n'];
        out = horzcat(cols{:});
        fprintf(fid, fmt, out');
    end

    for k = 1:numel(mesh.cells)
        cb = mesh.cells(k);
        if ~any(cb.type == legal_types)
            warning("meshio:ply:skipType", ...
                "cell_type ""%s"" is not supported by PLY format - skipping", cb.type);
            continue
        end
        d = cb.data;
        N = size(d, 2);
        nrows = size(d, 1);
        if nrows == 0, continue, end
        fmt = ['%d', repmat(' %d', 1, N), '\n'];
        out = [N * ones(nrows, 1), double(d) - 1];
        fprintf(fid, fmt, out');
    end
end


function write_binary_body(fid, mesh, pd_values, legal_types, cell_dtype)
    points = mesh.points;
    npts = size(points, 1);
    ncols_pts = size(points, 2);
    points_type = class(points);

    % Per-vertex: write each property in order. Slow but correct.
    for v = 1:npts
        for d = 1:ncols_pts
            fwrite(fid, points(v, d), points_type);
        end
        for i = 1:numel(pd_values)
            fwrite(fid, pd_values{i}(v), class(pd_values{i}));
        end
    end

    for k = 1:numel(mesh.cells)
        cb = mesh.cells(k);
        if ~any(cb.type == legal_types)
            warning("meshio:ply:skipType", ...
                "cell_type ""%s"" is not supported by PLY format - skipping", cb.type);
            continue
        end
        d = cb.data;
        N = size(d, 2);
        for r = 1:size(d, 1)
            fwrite(fid, uint8(N), 'uint8');
            fwrite(fid, cast(d(r, :) - 1, cell_dtype), cell_dtype);
        end
    end
end


function t = matlab_to_ply_type(matlab_type)
    switch matlab_type
        case 'int8',   t = "int8";
        case 'uint8',  t = "uint8";
        case 'int16',  t = "int16";
        case 'uint16', t = "uint16";
        case 'int32',  t = "int32";
        case 'uint32', t = "uint32";
        case 'int64',  t = "int64";
        case 'uint64', t = "uint64";
        case 'single', t = "float";
        case 'double', t = "double";
        otherwise
            error("meshio:WriteError", "Unsupported MATLAB type '%s' for PLY.", matlab_type);
    end
end
