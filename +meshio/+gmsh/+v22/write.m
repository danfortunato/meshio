function write(filename, mesh, options)
% WRITE  Write a Gmsh 2.2 file. Mirrors meshio.gmsh._gmsh22.write.
    arguments
        filename
        mesh              (1,1) meshio.Mesh
        options.binary    (1,1) logical     = true
        options.float_fmt (1,1) string      = ".16e"
    end

    % Filter the point data: gmsh:dim_tags are tags, the rest is actual point data.
    point_data = configureDictionary("string", "cell");
    pk = keys(mesh.point_data);
    for i = 1:numel(pk)
        if pk(i) ~= "gmsh:dim_tags"
            point_data{pk(i)} = mesh.point_data{pk(i)};
        end
    end

    % Split the cell data: gmsh:physical and gmsh:geometrical are tags,
    % the rest is actual cell data.
    tag_data  = configureDictionary("string", "cell");
    cell_data = configureDictionary("string", "cell");
    ck = keys(mesh.cell_data);
    for i = 1:numel(ck)
        if any(ck(i) == ["gmsh:physical", "gmsh:geometrical", "cell_tags"])
            tag_data{ck(i)} = mesh.cell_data{ck(i)};
        else
            cell_data{ck(i)} = mesh.cell_data{ck(i)};
        end
    end

    % Always include the physical and geometrical tags. See also the quoted
    % excerpt from the gmsh documentation in the read_cells_ascii function.
    for tag = ["gmsh:physical", "gmsh:geometrical"]
        if ~isKey(tag_data, tag)
            warning("meshio:gmsh:zeroTags", ...
                "Appending zeros to replace the missing %s tag data.", extractAfter(tag, "gmsh:"));
            zs = cell(1, numel(mesh.cells));
            for k = 1:numel(mesh.cells)
                zs{k} = zeros(mesh.cells(k).len(), 1, 'int32');
            end
            tag_data{tag} = zs;
        end
    end

    [~, ~, native_endian] = computer;
    if options.binary
        fid = fopen(filename, 'w', lower(native_endian));
    else
        fid = fopen(filename, 'w');
    end
    if fid < 0
        error("meshio:WriteError", "Cannot open '%s' for writing.", filename);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    if options.binary
        fprintf(fid, "$MeshFormat\n2.2 1 8\n");
        fwrite(fid, int32(1), 'int32');
        fprintf(fid, "\n$EndMeshFormat\n");
    else
        fprintf(fid, "$MeshFormat\n2.2 0 8\n$EndMeshFormat\n");
    end

    if numEntries(mesh.field_data) > 0
        meshio.gmsh.common.write_physical_names(fid, mesh.field_data);
    end

    write_nodes(fid, mesh.points, options.float_fmt, options.binary);
    write_elements(fid, mesh.cells, tag_data, options.binary);
    if ~isempty(mesh.gmsh_periodic)
        write_periodic(fid, mesh.gmsh_periodic, options.float_fmt);
    end

    pk2 = keys(point_data);
    for i = 1:numel(pk2)
        meshio.gmsh.common.write_data(fid, "NodeData", pk2(i), point_data{pk2(i)}, options.binary);
    end
    cell_data_raw = meshio.internal.raw_from_cell_data(cell_data);
    ck2 = keys(cell_data_raw);
    for i = 1:numel(ck2)
        meshio.gmsh.common.write_data(fid, "ElementData", ck2(i), cell_data_raw{ck2(i)}, options.binary);
    end
end


function write_nodes(fid, points, float_fmt, binary)
    if size(points, 2) == 2
        points = [points, zeros(size(points, 1), 1)];
    end
    n = size(points, 1);
    fprintf(fid, "$Nodes\n%d\n", n);
    if binary
        for i = 1:n
            fwrite(fid, int32(i), 'int32');
            fwrite(fid, points(i, :), 'double');
        end
        fprintf(fid, "\n");
    else
        fmt = ['%d ', sprintf('%%%s %%%s %%%s', float_fmt, float_fmt, float_fmt), '\n'];
        out = [(1:n)', points];
        fprintf(fid, fmt, out');
    end
    fprintf(fid, "$EndNodes\n");
end


function write_elements(fid, cells, tag_data, binary)
    fprintf(fid, "$Elements\n");
    total = 0;
    for i = 1:numel(cells)
        total = total + size(cells(i).data, 1);
    end
    fprintf(fid, "%d\n", total);

    meshio_to_gmsh = meshio.gmsh.common.meshio_to_gmsh_type();

    % Build the per-block tag matrix (one column per tag name present).
    tag_names_in_order = strings(0);
    for name = ["gmsh:physical", "gmsh:geometrical", "cell_tags"]
        if isKey(tag_data, name)
            tag_names_in_order(end+1) = name; %#ok<AGROW>
        end
    end

    consecutive_index = 0;
    for k = 1:numel(cells)
        cb = cells(k);
        nodes = meshio.gmsh.common.meshio_to_gmsh_order(cb.type, cb.data);
        gmsh_t = meshio_to_gmsh(cb.type);
        nrows = size(nodes, 1);
        ncols = size(nodes, 2);

        % gather tags for this block
        fcd = zeros(nrows, 0, 'int32');
        for ti = 1:numel(tag_names_in_order)
            t = tag_data{tag_names_in_order(ti)}{k};
            fcd = [fcd, int32(t(:))]; %#ok<AGROW>
        end
        ntags = size(fcd, 2);

        if binary
            fwrite(fid, int32([gmsh_t, nrows, ntags]), 'int32');
            idxs = (consecutive_index + 1 : consecutive_index + nrows)';
            block = int32([idxs, fcd, nodes]);
            fwrite(fid, block', 'int32');
        else
            tag_fmt = repmat(' %d', 1, ntags);
            fmt = ['%d ', num2str(gmsh_t), ' ', num2str(ntags), tag_fmt, ...
                   repmat(' %d', 1, ncols), '\n'];
            out = [(consecutive_index + 1 : consecutive_index + nrows)', ...
                   double(fcd), nodes];
            fprintf(fid, fmt, out');
        end
        consecutive_index = consecutive_index + nrows;
    end
    if binary
        fprintf(fid, "\n");
    end
    fprintf(fid, "$EndElements\n");
end


function write_periodic(fid, periodic, float_fmt)
    % $Periodic in gmsh 2.2 is always ASCII, even in otherwise-binary files.
    fprintf(fid, "$Periodic\n%d\n", numel(periodic));
    for k = 1:numel(periodic)
        entry = periodic{k};
        dim    = entry{1};
        stag   = entry{2}(1);
        mtag   = entry{2}(2);
        affine = entry{3};
        sm     = entry{4};
        fprintf(fid, "%d %d %d\n", dim, stag, mtag);
        if ~isempty(affine)
            fprintf(fid, "Affine");
            fmt = repmat([' %' char(float_fmt)], 1, numel(affine));
            fprintf(fid, [fmt, '\n'], double(affine));
        end
        sm1 = sm + 1;   % Add one, Gmsh is 0-based
        fprintf(fid, "%d\n", size(sm1, 1));
        fprintf(fid, "%d %d\n", sm1');
    end
    fprintf(fid, "$EndPeriodic\n");
end
