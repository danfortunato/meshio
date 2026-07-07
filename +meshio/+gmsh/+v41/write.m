function write(filename, mesh, options)
% WRITE  Write a Gmsh 4.1 file. Mirrors meshio.gmsh._gmsh41.write.
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

    [~, ~, native_endian] = computer;
    data_size = 8;
    if options.binary
        fid = fopen(filename, 'w', lower(native_endian));
    else
        fid = fopen(filename, 'w');
    end
    if fid < 0
        error("meshio:WriteError", "Cannot open '%s' for writing.", filename);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    file_type = double(options.binary);
    fprintf(fid, "$MeshFormat\n4.1 %d %d\n", file_type, data_size);
    if options.binary
        fwrite(fid, int32(1), 'int32');
        fprintf(fid, "\n");
    end
    fprintf(fid, "$EndMeshFormat\n");

    if numEntries(mesh.field_data) > 0
        meshio.gmsh.common.write_physical_names(fid, mesh.field_data);
    end

    write_entities(fid, mesh.cells, tag_data, mesh.cell_sets, mesh.point_data, options.binary);
    write_nodes(fid, mesh.points, mesh.cells, mesh.point_data, options.float_fmt, options.binary);
    write_elements(fid, mesh.cells, tag_data, options.binary);
    if ~isempty(mesh.gmsh_periodic)
        write_periodic(fid, mesh.gmsh_periodic, options.float_fmt, options.binary);
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


function write_entities(fid, cells, tag_data, cell_sets, point_data, binary)
    % Write entity section in a .msh file.
    %
    % The entity section links up to three kinds of information:
    %     1) The geometric objects represented in the mesh.
    %     2) Physical tags of geometric objects. This data will be a subset
    %        of that represented in 1)
    %     3) Which geometric objects form the boundary of this object.
    %        The boundary is formed of objects with dimension 1 less than
    %        the current one. A boundary can only be specified for objects
    %        of dimension at least 1.
    %
    % The entities of all geometric objects is pulled from
    % point_data['gmsh:dim_tags']. For details, see write_nodes().
    %
    % Physical tags are specified as tag_data, while the boundary of a
    % geometric object is specified in cell_sets.

    % The data format for the entities section is
    %
    %    numPoints(size_t) numCurves(size_t)
    %      numSurfaces(size_t) numVolumes(size_t)
    %    pointTag(int) X(double) Y(double) Z(double)
    %      numPhysicalTags(size_t) physicalTag(int) ...
    %    ...
    %    curveTag(int) minX(double) minY(double) minZ(double)
    %      maxX(double) maxY(double) maxZ(double)
    %      numPhysicalTags(size_t) physicalTag(int) ...
    %      numBoundingPoints(size_t) pointTag(int) ...
    %    ...
    %    surfaceTag(int) minX(double) minY(double) minZ(double)
    %      maxX(double) maxY(double) maxZ(double)
    %      numPhysicalTags(size_t) physicalTag(int) ...
    %      numBoundingCurves(size_t) curveTag(int) ...
    %    ...
    %    volumeTag(int) minX(double) minY(double) minZ(double)
    %      maxX(double) maxY(double) maxZ(double)
    %      numPhysicalTags(size_t) physicalTag(int) ...
    %      numBoundingSurfaces(size_t) surfaceTag(int) ...

    % Both nodes and cells have entities, but the cell entities are a subset
    % of the nodes. The reason is (if the inner workings of Gmsh has been
    % correctly understood) that node entities are assigned to all objects
    % necessary to specify the geometry whereas only cells of Physical
    % objects (gmsh jargon) are present among the cell entities.
    % The entities section must therefore be built on the node-entities, if
    % these are available. If this is not the case, we leave this section
    % blank.
    if ~isKey(point_data, "gmsh:dim_tags")
        return
    end

    fprintf(fid, "$Entities\n");

    % Array of entity tag (first column) and dimension (second column) per node.
    % We need to combine the two, since entity tags are reset for each dimension.
    % Uniquify, so that each row in node_dim_tags represents a unique entity.
    dim_tags = double(point_data{"gmsh:dim_tags"});
    node_dim_tags = unique(dim_tags, 'rows');

    % Write number of entities per dimension
    num_occ = zeros(1, 4);
    for d = 0:3
        num_occ(d + 1) = sum(node_dim_tags(:, 1) == d);
    end
    if binary
        fwrite(fid, uint64(num_occ), 'uint64');
    else
        fprintf(fid, "%d %d %d %d\n", num_occ);
    end

    % Array of dimension and entity tag per cell. Will be compared with the
    % similar node array.
    cell_dim_tags = zeros(numel(cells), 2);
    for ci = 1:numel(cells)
        cell_dim_tags(ci, :) = [cells(ci).dim, tag_data{"gmsh:geometrical"}{ci}(1)];
    end

    % We will only deal with bounding entities if this information is available.
    has_bound = isKey(cell_sets, "gmsh:bounding_entities");

    % The node entities form a superset of cell entities. Write entity
    % information based on nodes, supplement with cell information when
    % there is a matching cell block.
    for r = 1:size(node_dim_tags, 1)
        dim = node_dim_tags(r, 1);
        tag = node_dim_tags(r, 2);
        % Find the matching cell block, if it exists.
        match = find(cell_dim_tags(:, 1) == dim & cell_dim_tags(:, 2) == tag, 1);

        if binary
            fwrite(fid, int32(tag), 'int32');
            if dim == 0
                fwrite(fid, zeros(3, 1, 'double'), 'double');
            else
                fwrite(fid, zeros(6, 1, 'double'), 'double');
            end
        else
            fprintf(fid, "%d ", tag);
            if dim == 0
                fprintf(fid, "0 0 0 ");
            else
                fprintf(fid, "0 0 0 0 0 0 ");
            end
        end

        if ~isempty(match)
            physical_tag = double(tag_data{"gmsh:physical"}{match}(1));
            if binary
                fwrite(fid, uint64(1), 'uint64');
                fwrite(fid, int32(physical_tag), 'int32');
            else
                fprintf(fid, "1 %d ", physical_tag);
            end
        else
            if binary
                fwrite(fid, uint64(0), 'uint64');
            else
                fprintf(fid, "0 ");
            end
        end

        if dim > 0
            if has_bound && ~isempty(match)
                bounds = double(cell_sets{"gmsh:bounding_entities"}{match});
                if numel(bounds) > 0
                    if binary
                        fwrite(fid, uint64(numel(bounds)), 'uint64');
                        fwrite(fid, int32(bounds), 'int32');
                    else
                        fprintf(fid, "%d ", numel(bounds));
                        fprintf(fid, "%d ", bounds);
                        fprintf(fid, "\n");
                    end
                else
                    if binary
                        fwrite(fid, uint64(0), 'uint64');
                    else
                        fprintf(fid, "0\n");
                    end
                end
            else
                if binary
                    fwrite(fid, uint64(0), 'uint64');
                else
                    fprintf(fid, "0\n");
                end
            end
        else
            if ~binary
                fprintf(fid, "\n");
            end
        end
    end

    if binary
        fprintf(fid, "\n");
    end
    fprintf(fid, "$EndEntities\n");
end


function write_nodes(fid, points, cells, point_data, float_fmt, binary)
    % Write node information.
    %
    % If data on dimension and tags of the geometric entities which the
    % nodes belong to is available, the nodes will be grouped accordingly.
    % This data is specified as point_data, using the key 'gmsh:dim_tags'
    % and data as an num_points x 2 array (first column is the dimension of
    % the geometric entity of this node, second is the tag).
    %
    % If dim_tags are not available, all nodes will be assigned the same
    % tag of 0. This only makes sense if a single cell block is present in
    % the mesh; an error will be raised if numel(cells) > 1.
    if size(points, 2) == 2
        % msh4 requires 3D points, but 2D points given.
        % Appending 0 third component.
        points = [points, zeros(size(points, 1), 1)];
    end
    n = size(points, 1);

    fprintf(fid, "$Nodes\n");

    % The format for the nodes section is
    %
    % $Nodes
    %   numEntityBlocks(size_t) numNodes(size_t) minNodeTag(size_t) maxNodeTag(size_t)
    %   entityDim(int) entityTag(int) parametric(int; 0 or 1)
    %   numNodesInBlock(size_t)
    %     nodeTag(size_t)
    %     ...
    %     x(double) y(double) z(double)
    %        < u(double; if parametric and entityDim >= 1) >
    %        < v(double; if parametric and entityDim >= 2) >
    %        < w(double; if parametric and entityDim == 3) >
    %     ...
    %   ...
    % $EndNodes

    % If node (entity) tag and dimension is available, we make a list of
    % unique combinations thereof, and a map from the full node set to the
    % unique set.
    if isKey(point_data, "gmsh:dim_tags")
        % reverse_index_map maps from all nodes to their respective
        % representation in (the uniquified) node_dim_tags. This approach
        % works for general orderings of the nodes.
        [node_dim_tags, ~, reverse_index_map] = ...
            unique(double(point_data{"gmsh:dim_tags"}), 'rows');
    else
        % If entity information is not provided, we will assign the same
        % entity for all nodes. This only makes sense if the cells are of
        % a single type.
        if numel(cells) ~= 1
            error("meshio:WriteError", ...
                "Specify entity information (gmsh:dim_tags in point_data) to deal with more than one cell type.");
        end
        node_dim_tags = [double(cells(1).dim), 0];
        % All nodes map to the (single) dimension-entity object.
        reverse_index_map = ones(n, 1);
    end

    num_blocks = size(node_dim_tags, 1);
    min_tag = 1;
    max_tag = n;
    is_parametric = 0;

    % First write preamble.
    if binary
        fwrite(fid, uint64([num_blocks, n, min_tag, max_tag]), 'uint64');
    else
        fprintf(fid, "%d %d %d %d\n", num_blocks, n, min_tag, max_tag);
    end

    for j = 1:num_blocks
        dim = node_dim_tags(j, 1);
        tag = node_dim_tags(j, 2);
        node_tags = find(reverse_index_map == j);
        num_this = numel(node_tags);

        if binary
            fwrite(fid, int32([dim, tag, is_parametric]), 'int32');
            fwrite(fid, uint64(num_this), 'uint64');
            fwrite(fid, uint64(node_tags), 'uint64');
            blk_pts = points(node_tags, :);
            fwrite(fid, blk_pts', 'double');
        else
            fprintf(fid, "%d %d %d %d\n", dim, tag, is_parametric, num_this);
            fprintf(fid, "%d\n", node_tags);
            fmt = [sprintf('%%%s %%%s %%%s', float_fmt, float_fmt, float_fmt), '\n'];
            fprintf(fid, fmt, points(node_tags, :)');
        end
    end

    if binary
        fprintf(fid, "\n");
    end
    fprintf(fid, "$EndNodes\n");
end


function write_elements(fid, cells, tag_data, binary)
    % Write the $Elements block.
    %
    % $Elements
    %   numEntityBlocks(size_t)
    %   numElements(size_t) minElementTag(size_t) maxElementTag(size_t)
    %   entityDim(int) entityTag(int) elementType(int) numElementsInBlock(size_t)
    %     elementTag(size_t) nodeTag(size_t) ...
    %     ...
    %   ...
    % $EndElements
    fprintf(fid, "$Elements\n");
    total = 0;
    for i = 1:numel(cells)
        total = total + size(cells(i).data, 1);
    end
    num_blocks = numel(cells);
    min_tag = 1;
    max_tag = total;

    meshio_to_gmsh = meshio.gmsh.common.meshio_to_gmsh_type();

    if binary
        fwrite(fid, uint64([num_blocks, total, min_tag, max_tag]), 'uint64');
        tag0 = 1;
        for ci = 1:numel(cells)
            cb = cells(ci);
            node_idcs = meshio.gmsh.common.meshio_to_gmsh_order(cb.type, cb.data);
            % The entity tag should be equal within a CellBlock.
            if isKey(tag_data, "gmsh:geometrical")
                entity_tag = double(tag_data{"gmsh:geometrical"}{ci}(1));
            else
                entity_tag = 0;
            end
            fwrite(fid, int32([cb.dim, entity_tag, meshio_to_gmsh(cb.type)]), 'int32');
            n = size(node_idcs, 1);
            fwrite(fid, uint64(n), 'uint64');
            tags = (tag0 : tag0 + n - 1)';
            block = uint64([tags, node_idcs]);
            fwrite(fid, block', 'uint64');
            tag0 = tag0 + n;
        end
        fprintf(fid, "\n");
    else
        fprintf(fid, "%d %d %d %d\n", num_blocks, total, min_tag, max_tag);
        tag0 = 1;
        for ci = 1:numel(cells)
            cb = cells(ci);
            node_idcs = meshio.gmsh.common.meshio_to_gmsh_order(cb.type, cb.data);
            % The entity tag should be equal within a CellBlock.
            if isKey(tag_data, "gmsh:geometrical")
                entity_tag = double(tag_data{"gmsh:geometrical"}{ci}(1));
            else
                entity_tag = 0;
            end
            n = size(node_idcs, 1);
            fprintf(fid, "%d %d %d %d\n", cb.dim, entity_tag, meshio_to_gmsh(cb.type), n);
            fmt = ['%d', repmat(' %d', 1, size(node_idcs, 2)), '\n'];
            tags = (tag0 : tag0 + n - 1)';
            out = [tags, node_idcs];
            fprintf(fid, fmt, out');
            tag0 = tag0 + n;
        end
    end
    fprintf(fid, "$EndElements\n");
end


function write_periodic(fid, periodic, float_fmt, binary)
    % Write the $Periodic block.
    %
    % $Periodic
    %   numPeriodicLinks(size_t)
    %   entityDim(int) entityTag(int) entityTagMaster(int)
    %   numAffine(size_t) value(double) ...
    %   numCorrespondingNodes(size_t)
    %     nodeTag(size_t) nodeTagMaster(size_t)
    %     ...
    %   ...
    % $EndPeriodic
    fprintf(fid, "$Periodic\n");
    if binary
        fwrite(fid, uint64(numel(periodic)), 'uint64');
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
            if isempty(affine)
                fwrite(fid, uint64(0), 'uint64');
            else
                fwrite(fid, uint64(numel(affine)), 'uint64');
                fwrite(fid, double(affine), 'double');
            end
            fwrite(fid, uint64(size(sm, 1)), 'uint64');
            sm1 = uint64(sm + 1);   % Add one, Gmsh is 1-based
            fwrite(fid, sm1', 'uint64');
        else
            fprintf(fid, "%d %d %d\n", dim, stag, mtag);
            if isempty(affine)
                fprintf(fid, "0\n");
            else
                fprintf(fid, "%d ", numel(affine));
                fmt = repmat([' %' char(float_fmt)], 1, numel(affine));
                fprintf(fid, [fmt, '\n'], affine);
            end
            fprintf(fid, "%d\n", size(sm, 1));
            sm1 = sm + 1;   % Add one, Gmsh is 1-based
            fprintf(fid, "%d %d\n", sm1');
        end
    end
    if binary
        fprintf(fid, "\n");
    end
    fprintf(fid, "$EndPeriodic\n");
end
