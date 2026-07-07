function write(filename, mesh, options)
% WRITE  Write a TetGen .node + .ele pair.
%   Mirrors meshio.tetgen._tetgen.write.
    arguments
        filename
        mesh (1,1) meshio.Mesh
        options.float_fmt (1,1) string = ".16e"
    end

    [base, ext] = split_ext(filename);
    if ext == ".node"
        node_filename = filename;
        ele_filename  = base + ".ele";
    elseif ext == ".ele"
        node_filename = base + ".node";
        ele_filename  = filename;
    else
        error("meshio:WriteError", ...
            "Must specify .node or .ele file. Got %s.", filename);
    end

    if size(mesh.points, 2) ~= 3
        error("meshio:WriteError", "Can only write 3D points");
    end

    write_nodes(node_filename, mesh, options.float_fmt);
    write_elements(ele_filename, mesh);
end


function write_nodes(filename, mesh, float_fmt)
    % identify ":ref" key
    attr_keys = keys(mesh.point_data);
    is_ref = contains(attr_keys, ":ref");
    if numel(attr_keys) > 0
        if any(is_ref)
            ref_keys = attr_keys(find(is_ref, 1));
            attr_keys = attr_keys(attr_keys ~= ref_keys(1));
        else
            ref_keys = attr_keys(1);
            attr_keys = attr_keys(2:end);
        end
    else
        ref_keys = strings(0);
    end

    nattr = numel(attr_keys);
    nref  = numel(ref_keys);

    fid = fopen(filename, 'w');
    if fid < 0
        error("meshio:WriteError", "Cannot open '%s' for writing.", filename);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, "# This file was created by meshio (matlab port)\n");
    if (nattr + nref) > 0
        all_keys = [attr_keys(:); ref_keys(:)];
        fprintf(fid, "# attribute and marker names: %s\n", strjoin(all_keys, ", "));
    end
    n = size(mesh.points, 1);
    fprintf(fid, "%d %d %d %d\n", n, 3, nattr, nref);

    fmt = ['%d', repmat([' %', char(float_fmt)], 1, 3 + nattr), repmat(' %d', 1, nref), '\n'];

    cols = zeros(n, 3 + nattr + nref);
    cols(:, 1:3) = mesh.points;
    for k = 1:nattr
        cols(:, 3 + k) = mesh.point_data{attr_keys(k)};
    end
    for k = 1:nref
        cols(:, 3 + nattr + k) = mesh.point_data{ref_keys(k)};
    end
    idx = (0 : n - 1)';
    out = [idx, cols];
    fprintf(fid, fmt, out');
end


function write_elements(filename, mesh)
    attr_keys = keys(mesh.cell_data);
    is_ref = contains(attr_keys, ":ref");
    if numel(attr_keys) > 0
        if any(is_ref)
            ref_key = attr_keys(find(is_ref, 1));
            attr_keys = attr_keys(attr_keys ~= ref_key);
            attr_keys = [ref_key; attr_keys(:)];
        end
    end
    nattr = numel(attr_keys);

    % warn if any non-tetra blocks present (skipped silently here)
    skipped = strings(0);
    for i = 1:numel(mesh.cells)
        if mesh.cells(i).type ~= "tetra"
            skipped(end+1) = mesh.cells(i).type; %#ok<AGROW>
        end
    end
    if ~isempty(skipped)
        warning("meshio:tetgen:skip", ...
            "TetGen only supports tetrahedra, but mesh has %s. Skipping those.", ...
            strjoin(unique(skipped), ", "));
    end

    fid = fopen(filename, 'w');
    if fid < 0
        error("meshio:WriteError", "Cannot open '%s' for writing.", filename);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    fprintf(fid, "# This file was created by meshio (matlab port)\n");
    if nattr > 0
        fprintf(fid, "# attribute names: %s\n", strjoin(attr_keys, ", "));
    end

    tetra_idx = 0;
    for ci = 1:numel(mesh.cells)
        cb = mesh.cells(ci);
        if cb.type ~= "tetra", continue, end
        n = size(cb.data, 1);
        fprintf(fid, "%d %d %d\n", n, 4, nattr);
        % MATLAB 1-based -> file 0-based (matches Python writer convention)
        nodes_0 = cb.data - 1;
        cols = nodes_0;
        for k = 1:nattr
            cols = [cols, mesh.cell_data{attr_keys(k)}{ci}(:)]; %#ok<AGROW>
        end
        idx = (0 : n - 1)';
        out = [idx, cols];
        fmt = ['%d', repmat(' %d', 1, 4 + nattr), '\n'];
        fprintf(fid, fmt, out');
        tetra_idx = tetra_idx + 1; %#ok<NASGU>
    end
end


function [base, ext] = split_ext(filename)
    filename = string(filename);
    [d, n, e] = fileparts(filename);
    base = fullfile(d, n);
    ext = lower(string(e));
end
