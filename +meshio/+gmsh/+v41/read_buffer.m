function mesh = read_buffer(fid, is_ascii, data_size)
% READ_BUFFER  Read body of a Gmsh 4.1 file (as used by Gmsh 4.2.2+).
%   Mirrors meshio.gmsh._gmsh41.read_buffer.
%   The format is specified at <http://gmsh.info/doc/texinfo/gmsh.html#MSH-file-format>.
    arguments
        fid
        is_ascii  (1,1) logical
        data_size (1,1) double
    end
    if data_size ~= 8
        error("meshio:ReadError", ...
            "Only data_size=8 (size_t=uint64) supported in gmsh 4.1.");
    end

    % Initialize the optional data fields
    points            = zeros(0, 3);
    point_tags        = zeros(0, 1);
    point_entities    = zeros(0, 2);
    cells             = [];
    cell_tags         = configureDictionary("string", "cell");
    field_data        = configureDictionary("string", "cell");
    point_data        = configureDictionary("string", "cell");
    cell_data_raw     = configureDictionary("string", "cell");
    cell_sets         = configureDictionary("string", "cell");
    physical_tags     = [];
    bounding_entities = [];
    periodic          = {};

    while true
        [raw, eof] = read_nonempty_line(fid);
        if eof, break, end
        line = strtrim(string(raw));
        if extractBefore(line + " ", 2) ~= "$"
            error("meshio:ReadError", "Unexpected line %s", line);
        end
        environ = extractAfter(line, 1);

        switch environ
            case "PhysicalNames"
                field_data = meshio.gmsh.common.read_physical_names(fid, field_data);
            case "Entities"
                % Read physical tags and information on bounding entities.
                % The information is passed to the processing of elements.
                [physical_tags, bounding_entities] = read_entities(fid, is_ascii);
            case "Nodes"
                [points, point_tags, point_entities] = read_nodes(fid, is_ascii);
            case "Elements"
                [cells, cell_tags, cell_sets] = read_elements(fid, point_tags, ...
                    physical_tags, bounding_entities, field_data, is_ascii);
            case "Periodic"
                periodic = read_periodic(fid, is_ascii); %#ok<NASGU>
            case "NodeData"
                point_data = meshio.gmsh.common.read_data(fid, "NodeData", point_data, data_size, is_ascii);
            case "ElementData"
                cell_data_raw = meshio.gmsh.common.read_data(fid, "ElementData", cell_data_raw, data_size, is_ascii);
            otherwise
                % From <http://gmsh.info/doc/texinfo/gmsh.html#MSH-file-format>:
                %   Any section with an unrecognized header is simply ignored:
                %   you can thus add comments in a .msh file by putting them
                %   e.g. inside a $Comments/$EndComments section.
                meshio.gmsh.common.fast_forward_to_end_block(fid, environ);
        end
    end

    if isempty(cells)
        error("meshio:ReadError", "$Element section not found.");
    end

    cell_data = meshio.internal.cell_data_from_raw(cells, cell_data_raw);
    ck = keys(cell_tags);
    for i = 1:numel(ck)
        cell_data{ck(i)} = cell_tags{ck(i)};
    end

    % Add node entity information to the point data
    if size(point_entities, 1) > 0
        point_data{"gmsh:dim_tags"} = point_entities;
    end

    mesh = meshio.Mesh(points, cells, ...
        point_data = point_data, ...
        cell_data  = cell_data, ...
        field_data = field_data, ...
        cell_sets  = cell_sets, ...
        gmsh_periodic = periodic);
end


function [line, eof] = read_nonempty_line(fid)
    eof = false;
    while true
        raw = fgetl(fid);
        if ~ischar(raw), line = ''; eof = true; return, end
        if ~isempty(strtrim(raw)), line = raw; return, end
    end
end


function [physical_tags, bounding_entities] = read_entities(fid, is_ascii)
    % Read the entity section. Return physical tags of the entities, and
    % (for entities of dimension > 0) the bounding entities (so points
    % that form the boundary of a line etc).
    % Note that the bounding box of the entities is disregarded. Adding
    % this is not difficult, but for the moment, the entropy of adding
    % more data does not seem warranted.
    physical_tags     = cell(1, 4);
    bounding_entities = cell(1, 4);
    for d = 1:4
        physical_tags{d}     = configureDictionary("int32", "cell");
        bounding_entities{d} = configureDictionary("int32", "cell");
    end

    if is_ascii
        nums = sscanf(fgetl(fid), '%lu');   % dims 0, 1, 2, 3
    else
        nums = double(fread(fid, 4, 'uint64=>uint64'));
    end

    for d = 1:4
        n = nums(d);
        for k = 1:n
            if is_ascii
                raw = fgetl(fid);
                vals = sscanf(raw, '%f')';
                tag = int32(vals(1));
                if d == 1
                    coord_n = 3;
                else
                    coord_n = 6;
                end
                idx = 1 + 1 + coord_n;
                num_phys = int32(vals(idx));
                phys = int32(vals(idx + 1 : idx + num_phys));
                physical_tags{d}{tag} = phys;
                idx = idx + 1 + double(num_phys);
                if d > 1
                    % Number of bounding entities
                    num_brep = int32(vals(idx));
                    % Store bounding entities
                    bnd = int32(vals(idx + 1 : idx + num_brep));
                    bounding_entities{d}{tag} = bnd;
                end
            else
                tag = double(fread(fid, 1, 'int32=>int32'));
                if d == 1
                    fread(fid, 3, 'double=>double');
                else
                    fread(fid, 6, 'double=>double');
                end
                num_phys = double(fread(fid, 1, 'uint64=>uint64'));
                phys = int32(fread(fid, num_phys, 'int32=>int32'))';
                physical_tags{d}{int32(tag)} = phys;
                if d > 1
                    num_brep = double(fread(fid, 1, 'uint64=>uint64'));
                    bnd = int32(fread(fid, num_brep, 'int32=>int32'))';
                    bounding_entities{d}{int32(tag)} = bnd;
                end
            end
        end
    end
    meshio.gmsh.common.fast_forward_to_end_block(fid, "Entities");
end


function [points, tags, dim_tags] = read_nodes(fid, is_ascii)
    % Read node data: Node coordinates and tags.
    % Also find the entities of the nodes, and store this as point_data.
    % Note that entity tags are 1-offset within each dimension, thus it is
    % necessary to keep track of both tag and dimension of the entity.

    % numEntityBlocks numNodes minNodeTag maxNodeTag (all size_t)
    if is_ascii
        meta = sscanf(fgetl(fid), '%lu');
    else
        meta = double(fread(fid, 4, 'uint64=>uint64'));
    end
    num_entity_blocks = meta(1);
    total = meta(2);

    points = zeros(total, 3);
    tags = zeros(total, 1);
    dim_tags = zeros(total, 2);

    % From <http://gmsh.info/doc/texinfo/gmsh.html#MSH-file-format>:
    % > [...] tags can be "sparse", i.e., do not have to constitute a continuous
    % > list of numbers (the format even allows them to not be ordered).
    %
    % Following https://github.com/nschloe/meshio/issues/388, we read the tags
    % and populate the points array accordingly, thereby preserving the order
    % of indices of nodes/points.
    idx = 0;
    for b = 1:num_entity_blocks
        % entityDim(int) entityTag(int) parametric(int) numNodes(size_t)
        if is_ascii
            header_ints = sscanf(fgetl(fid), '%d');
            dim = header_ints(1); entity_tag = header_ints(2);
            parametric = header_ints(3); n = header_ints(4);
        else
            header_ints = double(fread(fid, 3, 'int32=>int32'));
            dim = header_ints(1); entity_tag = header_ints(2); parametric = header_ints(3);
            n = double(fread(fid, 1, 'uint64=>uint64'));
        end
        if parametric ~= 0
            error("meshio:ReadError", "parametric nodes not implemented");
        end
        if is_ascii
            blk_tags = zeros(n, 1);
            for j = 1:n
                blk_tags(j) = sscanf(fgetl(fid), '%lu');
            end
            % x(double) y(double) z(double) (* numNodes)
            blk_pts = zeros(n, 3);
            for j = 1:n
                blk_pts(j, :) = sscanf(fgetl(fid), '%f')';
            end
        else
            blk_tags = double(fread(fid, n, 'uint64=>uint64'));
            blk_pts = fread(fid, [3, n], 'double=>double')';
        end
        % Store the point densely and in the order in which they appear in the file.
        tags(idx + 1 : idx + n) = blk_tags;
        points(idx + 1 : idx + n, :) = blk_pts;
        % Entity tag and entity dimension of the nodes. Stored as point-data.
        dim_tags(idx + 1 : idx + n, :) = repmat([dim, entity_tag], n, 1);
        idx = idx + n;
    end
    if ~is_ascii
        fgetl(fid);
    end
    meshio.gmsh.common.fast_forward_to_end_block(fid, "Nodes");
end


function [cells, cell_data, cell_sets] = read_elements(fid, point_tags, ...
        physical_tags, bounding_entities, field_data, is_ascii)
    % numEntityBlocks numElements minElementTag maxElementTag (all size_t)
    if is_ascii
        meta = sscanf(fgetl(fid), '%lu');
    else
        meta = double(fread(fid, 4, 'uint64=>uint64'));
    end
    num_entity_blocks = meta(1);

    gmsh_to_meshio = meshio.gmsh.common.gmsh_to_meshio_type();
    nnpc = meshio.internal.num_nodes_per_cell();

    cell_sets = configureDictionary("string", "cell");
    fd_keys = keys(field_data);
    for i = 1:numel(fd_keys)
        cell_sets{fd_keys(i)} = cell(1, num_entity_blocks);
    end

    blocks = cell(1, num_entity_blocks);

    for b = 1:num_entity_blocks
        % entityDim(int) entityTag(int) elementType(int) numElements(size_t)
        if is_ascii
            header_ints = sscanf(fgetl(fid), '%d');
            dim = header_ints(1); tag_entity = header_ints(2);
            type_ele = header_ints(3); num_ele = header_ints(4);
        else
            header_ints = double(fread(fid, 3, 'int32=>int32'));
            dim = header_ints(1); tag_entity = header_ints(2); type_ele = header_ints(3);
            num_ele = double(fread(fid, 1, 'uint64=>uint64'));
        end

        for i = 1:numel(fd_keys)
            pn = fd_keys(i);
            phys_info = field_data{pn};
            include = false;
            if ~isempty(physical_tags) && ~isempty(physical_tags{dim + 1}) && ...
               isKey(physical_tags{dim + 1}, int32(tag_entity))
                pt = physical_tags{dim + 1}{int32(tag_entity)};
                if double(phys_info(2)) == dim && any(double(pt) == double(phys_info(1)))
                    include = true;
                end
            end
            if include
                cell_sets{pn}{b} = (1:num_ele)';
            else
                cell_sets{pn}{b} = zeros(0, 1);
            end
        end

        t = gmsh_to_meshio(type_ele);
        npe = nnpc(t);
        if is_ascii
            recs = zeros(num_ele, 1 + npe);
            for j = 1:num_ele
                recs(j, :) = sscanf(fgetl(fid), '%lu')';
            end
        else
            recs = double(fread(fid, num_ele * (1 + npe), 'uint64=>uint64'));
            recs = reshape(recs, 1 + npe, num_ele)';
        end
        nodes = recs(:, 2:end);

        % Find physical tag, if defined; else it is None.
        if isempty(physical_tags) || isempty(physical_tags{dim + 1}) || ...
           ~isKey(physical_tags{dim + 1}, int32(tag_entity))
            pt = [];
        else
            pt = physical_tags{dim + 1}{int32(tag_entity)};
        end
        % Bounding entities (of lower dimension) if defined. Else it is None.
        if dim > 0 && ~isempty(bounding_entities) && ...   % Points have no boundaries
           ~isempty(bounding_entities{dim + 1}) && ...
           isKey(bounding_entities{dim + 1}, int32(tag_entity))
            be = bounding_entities{dim + 1}{int32(tag_entity)};
        else
            be = [];
        end

        blocks{b} = {pt, be, tag_entity, t, nodes};
    end

    if ~is_ascii
        fgetl(fid);
    end
    meshio.gmsh.common.fast_forward_to_end_block(fid, "Elements");

    % Inverse point tags
    if isempty(point_tags)
        remap = [];
    else
        remap = zeros(1, max(point_tags));
        remap(point_tags) = 1:numel(point_tags);
    end

    cells = meshio.CellBlock.empty(1, 0);
    phys_list = {};
    geom_list = {};
    has_phys = false;
    bound_list = {};
    has_bound = false;
    for i = 1:num_entity_blocks
        phys_tag = blocks{i}{1};
        bound    = blocks{i}{2};
        geom_tag = blocks{i}{3};
        t        = blocks{i}{4};
        gmsh_nodes = blocks{i}{5};
        if isempty(remap)
            matlab_nodes = gmsh_nodes;
        else
            matlab_nodes = remap(gmsh_nodes);
            if size(gmsh_nodes, 1) == 1
                matlab_nodes = reshape(matlab_nodes, 1, []);
            end
        end
        matlab_nodes = meshio.gmsh.common.gmsh_to_meshio_order(t, matlab_nodes);
        cells(end+1) = meshio.CellBlock(t, matlab_nodes); %#ok<AGROW>
        n = size(matlab_nodes, 1);
        if ~isempty(phys_tag)
            has_phys = true;
            phys_list{end+1} = repmat(int32(phys_tag(1)), n, 1); %#ok<AGROW>
        else
            phys_list{end+1} = zeros(n, 1, 'int32'); %#ok<AGROW>
        end
        geom_list{end+1} = repmat(int32(geom_tag), n, 1); %#ok<AGROW>
        % The bounding entities is stored in the cell_sets.
        if ~isempty(bounding_entities)
            has_bound = true;
            bound_list{end+1} = bound; %#ok<AGROW>
        end
    end

    cell_data = configureDictionary("string", "cell");
    if has_phys
        cell_data{"gmsh:physical"} = phys_list;
    end
    if ~isempty(geom_list)
        cell_data{"gmsh:geometrical"} = geom_list;
    end
    if has_bound
        cell_sets{"gmsh:bounding_entities"} = bound_list;
    end
end


function periodic = read_periodic(fid, is_ascii)
    % numPeriodicLinks(size_t)
    if is_ascii
        num_periodic = sscanf(fgetl(fid), '%lu');
    else
        num_periodic = double(fread(fid, 1, 'uint64=>uint64'));
    end
    periodic = cell(1, num_periodic);
    for k = 1:num_periodic
        % entityDim(int) entityTag(int) entityTagMaster(int)
        if is_ascii
            triplet = sscanf(fgetl(fid), '%d');
            edim = triplet(1); stag = triplet(2); mtag = triplet(3);
            % numAffine(size_t) value(double) ...
            num_affine = sscanf(fgetl(fid), '%lu');
            if num_affine > 0
                affine = fscanf(fid, '%f', [1, num_affine]);
                fgetl(fid);
            else
                affine = [];
            end
            % numCorrespondingNodes(size_t)
            num_nodes = sscanf(fgetl(fid), '%lu');
            % nodeTag(size_t) nodeTagMaster(size_t) ...
            sm = zeros(num_nodes, 2);
            for j = 1:num_nodes
                sm(j, :) = sscanf(fgetl(fid), '%lu')';
            end
        else
            triplet = double(fread(fid, 3, 'int32=>int32'));
            edim = triplet(1); stag = triplet(2); mtag = triplet(3);
            num_affine = double(fread(fid, 1, 'uint64=>uint64'));
            if num_affine > 0
                affine = fread(fid, num_affine, 'double=>double')';
            else
                affine = [];
            end
            num_nodes = double(fread(fid, 1, 'uint64=>uint64'));
            sm = double(fread(fid, 2 * num_nodes, 'uint64=>uint64'));
            sm = reshape(sm, 2, num_nodes)';
        end
        sm = sm - 1;   % Subtract one, meshio-internal is 0-based
        periodic{k} = {edim, [stag, mtag], affine, sm};
    end
    meshio.gmsh.common.fast_forward_to_end_block(fid, "Periodic");
end
