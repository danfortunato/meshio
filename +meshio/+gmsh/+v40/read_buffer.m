function mesh = read_buffer(fid, is_ascii, data_size)
% READ_BUFFER  Read body of a Gmsh 4.0 file (as used by Gmsh 4.1.5).
%   Mirrors meshio.gmsh._gmsh40.read_buffer.
%   The format is specified at
%   <http://gmsh.info//doc/texinfo/gmsh.html#MSH-file-format-_0028version-4_0029>.
    arguments
        fid
        is_ascii  (1,1) logical
        data_size (1,1) double
    end

    % Initialize the optional data fields
    points        = zeros(0, 3);
    point_tags    = zeros(0, 1);
    cells         = meshio.CellBlock.empty(1, 0);
    cell_tags     = configureDictionary("string", "cell");
    field_data    = configureDictionary("string", "cell");
    point_data    = configureDictionary("string", "cell");
    cell_data_raw = configureDictionary("string", "cell");
    physical_tags = [];
    periodic      = {};

    while true
        raw = fgetl(fid);
        if ~ischar(raw), break, end
        line = strtrim(string(raw));
        if line == "", continue, end
        if extractBefore(line + " ", 2) ~= "$"
            error("meshio:ReadError", "Unexpected line %s", line);
        end
        environ = extractAfter(line, 1);

        switch environ
            case "PhysicalNames"
                field_data = meshio.gmsh.common.read_physical_names(fid, field_data);
            case "Entities"
                physical_tags = read_entities(fid, is_ascii);
            case "Nodes"
                [points, point_tags] = read_nodes(fid, is_ascii);
            case "Elements"
                [cells, cell_tags] = read_elements(fid, point_tags, physical_tags, is_ascii);
            case "Periodic"
                periodic = read_periodic(fid, is_ascii); %#ok<NASGU>
            case "NodeData"
                point_data = meshio.gmsh.common.read_data(fid, "NodeData", point_data, data_size, is_ascii);
            case "ElementData"
                cell_data_raw = meshio.gmsh.common.read_data(fid, "ElementData", cell_data_raw, data_size, is_ascii);
            otherwise
                % From
                % <http://gmsh.info//doc/texinfo/gmsh.html#MSH-file-format-_0028version-4_0029>:
                %   Any section with an unrecognized header is simply ignored:
                %   you can thus add comments in a .msh file by putting them
                %   e.g. inside a $Comments/$EndComments section.
                meshio.gmsh.common.fast_forward_to_end_block(fid, environ);
        end
    end

    cell_data = meshio.internal.cell_data_from_raw(cells, cell_data_raw);
    ck = keys(cell_tags);
    for i = 1:numel(ck)
        cell_data{ck(i)} = cell_tags{ck(i)};
    end

    mesh = meshio.Mesh(points, cells, ...
        point_data = point_data, ...
        cell_data  = cell_data, ...
        field_data = field_data, ...
        gmsh_periodic = periodic);
end


function physical_tags = read_entities(fid, is_ascii)
    physical_tags = cell(1, 4);
    for d = 1:4
        physical_tags{d} = configureDictionary("int32", "cell");
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
                parts = sscanf(raw, '%f');
                tag = int32(parts(1));
                offset = 2;
                offset = offset + 6;   % discard boxMinX...boxMaxZ
                num_phys = int32(parts(offset));
                phys = int32(parts(offset+1 : offset+num_phys));
                physical_tags{d}{tag} = phys;
                % discard tagBREP{Vert,Curve,Surfaces}
            else
                tag = double(fread(fid, 1, 'int32=>int32'));
                fread(fid, 6, 'double=>double');   % discard boxMinX...boxMaxZ
                num_phys = double(fread(fid, 1, 'uint64=>uint64'));
                phys = int32(fread(fid, num_phys, 'int32=>int32'));
                physical_tags{d}{int32(tag)} = phys;
                if d > 1
                    % discard tagBREP{Vert,Curve,Surfaces}
                    num_brep = double(fread(fid, 1, 'uint64=>uint64'));
                    fread(fid, num_brep, 'int32=>int32');
                end
            end
        end
    end
    meshio.gmsh.common.fast_forward_to_end_block(fid, "Entities");
end


function [points, tags] = read_nodes(fid, is_ascii)
    if is_ascii
        % first line: numEntityBlocks(unsigned long) numNodes(unsigned long)
        parts = sscanf(fgetl(fid), '%d');
        num_entity_blocks = parts(1);
        total = parts(2);
        points = zeros(total, 3);
        tags = zeros(total, 1);
        idx = 0;
        for b = 1:num_entity_blocks
            % first line in the entity block:
            % tagEntity(int) dimEntity(int) typeNode(int) numNodes(unsigned long)
            header = sscanf(fgetl(fid), '%d');
            n = header(4);
            for j = 1:n
                % tag(int) x(double) y(double) z(double)
                row = sscanf(fgetl(fid), '%f');
                tags(idx + 1) = row(1);
                points(idx + 1, :) = row(2:4)';
                idx = idx + 1;
            end
        end
    else
        % numEntityBlocks(unsigned long) numNodes(unsigned long)
        meta = double(fread(fid, 2, 'uint64=>uint64'));
        num_entity_blocks = meta(1);
        points = zeros(0, 3);
        tags = zeros(0, 1);
        for b = 1:num_entity_blocks
            % tagEntity(int) dimEntity(int) typeNode(int) numNodes(unsigned long)
            fread(fid, 3, 'int32=>int32');
            n = double(fread(fid, 1, 'uint64=>uint64'));
            block_tags = zeros(n, 1);
            block_pts  = zeros(n, 3);
            for j = 1:n
                block_tags(j) = double(fread(fid, 1, 'int32=>int32'));
                block_pts(j, :) = fread(fid, 3, 'double=>double')';
            end
            tags = [tags; block_tags]; %#ok<AGROW>
            points = [points; block_pts]; %#ok<AGROW>
        end
        fgetl(fid);
    end
    meshio.gmsh.common.fast_forward_to_end_block(fid, "Nodes");
end


function [cells, cell_data] = read_elements(fid, point_tags, physical_tags, is_ascii)
    % numEntityBlocks(unsigned long) numElements(unsigned long)
    if is_ascii
        meta = sscanf(fgetl(fid), '%lu');
    else
        meta = double(fread(fid, 2, 'uint64=>uint64'));
    end
    num_entity_blocks = meta(1);

    gmsh_to_meshio = meshio.gmsh.common.gmsh_to_meshio_type();
    nnpc = meshio.internal.num_nodes_per_cell();

    blocks = {};

    for b = 1:num_entity_blocks
        % tagEntity(int) dimEntity(int) typeEle(int) numElements(unsigned long)
        if is_ascii
            header = sscanf(fgetl(fid), '%d');
            tag_entity = header(1);
            dim_entity = header(2);
            type_ele   = header(3);
            num_ele    = header(4);
            t = gmsh_to_meshio(type_ele);
            npe = nnpc(t);
            raw = zeros(num_ele, 1 + npe);
            for j = 1:num_ele
                raw(j, :) = sscanf(fgetl(fid), '%d')';
            end
            nodes = raw(:, 2:end);
        else
            header = double(fread(fid, 3, 'int32=>int32'));
            tag_entity = header(1);
            dim_entity = header(2);
            type_ele   = header(3);
            num_ele    = double(fread(fid, 1, 'uint64=>uint64'));
            t = gmsh_to_meshio(type_ele);
            npe = nnpc(t);
            recs = double(fread(fid, num_ele * (1 + npe), 'int32=>int32'));
            recs = reshape(recs, 1 + npe, num_ele)';
            nodes = recs(:, 2:end);
        end
        if isempty(physical_tags) || isempty(physical_tags{dim_entity + 1}) || ...
           ~isKey(physical_tags{dim_entity + 1}, int32(tag_entity))
            phys_tag = [];
        else
            phys_tag = physical_tags{dim_entity + 1}{int32(tag_entity)};
        end
        blocks{end+1} = {phys_tag, tag_entity, t, nodes}; %#ok<AGROW>
    end

    if ~is_ascii
        fgetl(fid);
    end
    meshio.gmsh.common.fast_forward_to_end_block(fid, "Elements");

    % The msh4 elements array refers to the nodes by their tag, not the index.
    % All other mesh formats use the index, which is far more efficient, too.
    % Hence, unfortunately, we have to do a fairly expensive conversion here.
    if isempty(point_tags)
        remap = [];
    else
        remap = zeros(1, max(point_tags));
        remap(point_tags) = 1:numel(point_tags);
    end

    cells = meshio.CellBlock.empty(1, 0);
    cell_data = configureDictionary("string", "cell");
    phys_list = {};
    geom_list = {};
    has_phys = false;
    for i = 1:numel(blocks)
        phys_tag = blocks{i}{1};
        geom_tag = blocks{i}{2};
        t        = blocks{i}{3};
        nodes    = blocks{i}{4};
        if ~isempty(remap)
            nodes = remap(nodes);
            if size(blocks{i}{4}, 1) == 1
                nodes = reshape(nodes, 1, []);
            end
        end
        nodes = meshio.gmsh.common.gmsh_to_meshio_order(t, nodes);
        cells(end+1) = meshio.CellBlock(t, nodes); %#ok<AGROW>
        if ~isempty(phys_tag)
            has_phys = true;
            phys_list{end+1} = repmat(int32(phys_tag(1)), size(nodes, 1), 1); %#ok<AGROW>
        else
            phys_list{end+1} = zeros(size(nodes, 1), 1, 'int32'); %#ok<AGROW>
        end
        geom_list{end+1} = repmat(int32(geom_tag), size(nodes, 1), 1); %#ok<AGROW>
    end
    if has_phys
        cell_data{"gmsh:physical"} = phys_list;
    end
    if ~isempty(geom_list)
        cell_data{"gmsh:geometrical"} = geom_list;
    end
end


function periodic = read_periodic(fid, is_ascii)
    if is_ascii
        num_periodic = sscanf(fgetl(fid), '%d');
    else
        num_periodic = double(fread(fid, 1, 'int32=>int32'));
    end
    periodic = cell(1, num_periodic);
    for k = 1:num_periodic
        if is_ascii
            triplet = sscanf(fgetl(fid), '%d');
            edim = triplet(1); stag = triplet(2); mtag = triplet(3);
            raw = strtrim(fgetl(fid));
            if startsWith(raw, "Affine")
                affine = sscanf(extractAfter(raw, 6), '%f')';
                num_nodes = sscanf(fgetl(fid), '%d');
            else
                affine = [];
                num_nodes = sscanf(raw, '%d');
            end
            sm = zeros(num_nodes, 2);
            for j = 1:num_nodes
                sm(j, :) = sscanf(fgetl(fid), '%d')';
            end
        else
            triplet = double(fread(fid, 3, 'int32=>int32'));
            edim = triplet(1); stag = triplet(2); mtag = triplet(3);
            num_nodes = double(fread(fid, 1, 'int64=>int64'));
            if num_nodes < 0
                affine = fread(fid, 16, 'double=>double')';
                num_nodes = double(fread(fid, 1, 'uint64=>uint64'));
            else
                affine = [];
            end
            sm = double(fread(fid, 2 * num_nodes, 'int32=>int32'));
            sm = reshape(sm, 2, num_nodes)';
        end
        sm = sm - 1;   % gmsh 1-based -> meshio internal 0-based for periodic
        periodic{k} = {edim, [stag, mtag], affine, sm};
    end
    meshio.gmsh.common.fast_forward_to_end_block(fid, "Periodic");
end
