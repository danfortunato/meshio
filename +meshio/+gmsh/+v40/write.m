function write(filename, mesh, options)
% WRITE  Write a Gmsh 4.0 file. Mirrors meshio.gmsh._gmsh40.write.
    arguments
        filename
        mesh              (1,1) meshio.Mesh
        options.binary    (1,1) logical     = true
        options.float_fmt (1,1) string      = ".16e"
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
        fprintf(fid, "$MeshFormat\n4.0 1 8\n");
        fwrite(fid, int32(1), 'int32');
        fprintf(fid, "\n$EndMeshFormat\n");
    else
        fprintf(fid, "$MeshFormat\n4.0 0 8\n$EndMeshFormat\n");
    end

    if numEntries(mesh.field_data) > 0
        meshio.gmsh.common.write_physical_names(fid, mesh.field_data);
    end

    write_nodes(fid, mesh.points, options.float_fmt, options.binary);
    write_elements(fid, mesh.cells, options.binary);
    if ~isempty(mesh.gmsh_periodic)
        write_periodic(fid, mesh.gmsh_periodic, options.float_fmt, options.binary);
    end

    pk = keys(mesh.point_data);
    for i = 1:numel(pk)
        meshio.gmsh.common.write_data(fid, "NodeData", pk(i), ...
            mesh.point_data{pk(i)}, options.binary);
    end
    cell_data_raw = meshio.internal.raw_from_cell_data(mesh.cell_data);
    ck = keys(cell_data_raw);
    for i = 1:numel(ck)
        meshio.gmsh.common.write_data(fid, "ElementData", ck(i), ...
            cell_data_raw{ck(i)}, options.binary);
    end
end


function write_nodes(fid, points, float_fmt, binary)
    if size(points, 2) == 2
        points = [points, zeros(size(points, 1), 1)];
    end
    n = size(points, 1);
    fprintf(fid, "$Nodes\n");

    % TODO not sure what dimEntity is supposed to say
    dim_entity = 0;
    type_node = 0;

    if binary
        % write all points as one big block
        % numEntityBlocks(unsigned long) numNodes(unsigned long)
        % tagEntity(int) dimEntity(int) typeNode(int) numNodes(unsigned long)
        % tag(int) x(double) y(double) z(double)
        fwrite(fid, uint64([1, n]), 'uint64');
        fwrite(fid, int32([1, dim_entity, type_node]), 'int32');
        fwrite(fid, uint64(n), 'uint64');
        for i = 1:n
            fwrite(fid, int32(i), 'int32');
            fwrite(fid, points(i, :), 'double');
        end
        fprintf(fid, "\n");
    else
        % write all points as one big block
        % numEntityBlocks(unsigned long) numNodes(unsigned long)
        fprintf(fid, "%d %d\n", 1, n);
        % tagEntity(int) dimEntity(int) typeNode(int) numNodes(unsigned long)
        fprintf(fid, "%d %d %d %d\n", 1, dim_entity, type_node, n);
        fmt = ['%d ', sprintf('%%%s %%%s %%%s', float_fmt, float_fmt, float_fmt), '\n'];
        out = [(1:n)', points];
        fprintf(fid, fmt, out');
    end
    fprintf(fid, "$EndNodes\n");
end


function write_elements(fid, cells, binary)
    % write elements
    fprintf(fid, "$Elements\n");
    total = 0;
    for i = 1:numel(cells)
        total = total + size(cells(i).data, 1);
    end
    meshio_to_gmsh = meshio.gmsh.common.meshio_to_gmsh_type();
    if binary
        fwrite(fid, uint64([numel(cells), total]), 'uint64');
        consecutive_index = 0;
        for k = 1:numel(cells)
            cb = cells(k);
            node_idcs = meshio.gmsh.common.meshio_to_gmsh_order(cb.type, cb.data);
            % tagEntity(int) dimEntity(int) typeEle(int) numElements(unsigned long)
            fwrite(fid, int32([1, cb.dim, meshio_to_gmsh(cb.type)]), 'int32');
            fwrite(fid, uint64(size(node_idcs, 1)), 'uint64');
            idxs = (consecutive_index : consecutive_index + size(node_idcs, 1) - 1)';
            block = int32([idxs, node_idcs]);
            fwrite(fid, block', 'int32');
            consecutive_index = consecutive_index + size(node_idcs, 1);
        end
        fprintf(fid, "\n");
    else
        % count all cells
        fprintf(fid, "%d %d\n", numel(cells), total);
        consecutive_index = 0;
        for k = 1:numel(cells)
            cb = cells(k);
            node_idcs = meshio.gmsh.common.meshio_to_gmsh_order(cb.type, cb.data);
            % tagEntity(int) dimEntity(int) typeEle(int) numElements(unsigned long)
            fprintf(fid, "%d %d %d %d\n", 1, cb.dim, meshio_to_gmsh(cb.type), size(node_idcs, 1));
            fmt = ['%d', repmat(' %d', 1, size(node_idcs, 2)), '\n'];
            idxs = (consecutive_index : consecutive_index + size(node_idcs, 1) - 1)';
            out = [idxs, node_idcs];
            fprintf(fid, fmt, out');
            consecutive_index = consecutive_index + size(node_idcs, 1);
        end
    end
    fprintf(fid, "$EndElements\n");
end


function write_periodic(fid, periodic, float_fmt, binary)
    fprintf(fid, "$Periodic\n");
    if binary
        fwrite(fid, int32(numel(periodic)), 'int32');
    else
        fprintf(fid, "%d\n", numel(periodic));
    end
    for k = 1:numel(periodic)
        entry = periodic{k};
        dim    = entry{1};
        stag   = entry{2}(1);
        mtag   = entry{2}(2);
        affine = entry{3};
        sm     = entry{4};
        if binary
            fwrite(fid, int32([dim, stag, mtag]), 'int32');
            if ~isempty(affine)
                fwrite(fid, int64(-1), 'int64');
                fwrite(fid, double(affine), 'double');
                fwrite(fid, uint64(size(sm, 1)), 'uint64');
            else
                fwrite(fid, int64(size(sm, 1)), 'int64');
            end
            sm1 = int32(sm + 1);   % Add one, Gmsh is 1-based
            fwrite(fid, sm1', 'int32');
        else
            fprintf(fid, "%d %d %d\n", dim, stag, mtag);
            if ~isempty(affine)
                fprintf(fid, "Affine");
                fmt = repmat([' %' char(float_fmt)], 1, numel(affine));
                fprintf(fid, [fmt, '\n'], affine);
                fprintf(fid, "%d\n", size(sm, 1));
            else
                fprintf(fid, "%d\n", size(sm, 1));
            end
            sm1 = sm + 1;   % Add one, Gmsh is 1-based
            fprintf(fid, "%d %d\n", sm1');
        end
    end
    if binary
        fprintf(fid, "\n");
    end
    fprintf(fid, "$EndPeriodic\n");
end
