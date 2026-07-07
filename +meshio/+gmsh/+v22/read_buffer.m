function mesh = read_buffer(fid, is_ascii, data_size)
% READ_BUFFER  Read body of a Gmsh 2.2 file.
%   Mirrors meshio.gmsh._gmsh22.read_buffer.
%   The format is specified at
%   <http://gmsh.info//doc/texinfo/gmsh.html#MSH-ASCII-file-format>.
    arguments
        fid
        is_ascii  (1,1) logical
        data_size (1,1) double
    end

    % Initialize the optional data fields
    points                  = zeros(0, 3);
    point_tags              = zeros(0, 1);
    cells                   = meshio.CellBlock.empty(1, 0);
    field_data              = configureDictionary("string", "cell");
    point_data              = configureDictionary("string", "cell");
    cell_data_raw           = configureDictionary("string", "cell");
    cell_tags_by_block      = struct('physical', {{}}, 'geometrical', {{}});
    has_additional_tag_data = false;
    periodic                = {};

    while true
        % fast-forward over blank lines
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
            case "Nodes"
                [points, point_tags] = read_nodes(fid, is_ascii);
            case "Elements"
                [cells, cell_tags_by_block, has_additional_tag_data] = ...
                    read_cells(fid, point_tags, is_ascii);
            case "Periodic"
                periodic = read_periodic(fid);
            case "NodeData"
                point_data = meshio.gmsh.common.read_data(fid, "NodeData", point_data, data_size, is_ascii);
            case "ElementData"
                cell_data_raw = meshio.gmsh.common.read_data(fid, "ElementData", cell_data_raw, data_size, is_ascii);
            otherwise
                meshio.gmsh.common.fast_forward_to_end_block(fid, environ);
        end
    end

    if has_additional_tag_data
        warning("meshio:gmsh:additionalTags", ...
            "The file contains tag data that couldn't be processed.");
    end

    cell_data = meshio.internal.cell_data_from_raw(cells, cell_data_raw);

    % merge cell_tags into cell_data
    if ~isempty(cells)
        if any(cellfun(@(x) ~isempty(x), cell_tags_by_block.physical))
            cell_data{"gmsh:physical"} = cell_tags_by_block.physical;
        end
        if any(cellfun(@(x) ~isempty(x), cell_tags_by_block.geometrical))
            cell_data{"gmsh:geometrical"} = cell_tags_by_block.geometrical;
        end
    end

    mesh = meshio.Mesh(points, cells, ...
        point_data = point_data, ...
        cell_data  = cell_data, ...
        field_data = field_data, ...
        gmsh_periodic = periodic);
end


function periodic = read_periodic(fid)
    num_periodic = sscanf(fgetl(fid), '%d');
    periodic = cell(1, num_periodic);
    for k = 1:num_periodic
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
        sm = sm - 1;   % Subtract one, meshio internal is 0-based
        periodic{k} = {edim, [stag, mtag], affine, sm};
    end
    meshio.gmsh.common.fast_forward_to_end_block(fid, "Periodic");
end


function [line, eof] = read_nonempty_line(fid)
    eof = false;
    while true
        raw = fgetl(fid);
        if ~ischar(raw), line = ''; eof = true; return, end
        if ~isempty(strtrim(raw)), line = raw; return, end
    end
end


function [points, point_tags] = read_nodes(fid, is_ascii)
    % The first line is the number of nodes
    n = sscanf(fgetl(fid), '%d');
    if is_ascii
        data = fscanf(fid, '%f', [4, n])';
        % The first number is the index
        point_tags = data(:, 1);
        points = data(:, 2:4);
    else
        % binary
        points = zeros(n, 3);
        point_tags = zeros(n, 1);
        for i = 1:n
            point_tags(i) = double(fread(fid, 1, 'int32=>int32'));
            points(i, :)  = fread(fid, 3, 'double=>double')';
        end
    end
    meshio.gmsh.common.fast_forward_to_end_block(fid, "Nodes");
end


function [cells, tags_by_block, has_additional] = read_cells(fid, point_tags, is_ascii)
    % The first line is the number of elements
    total = sscanf(fgetl(fid), '%d');
    if is_ascii
        [blocks, tag_arrays, has_additional] = read_cells_ascii(fid, total);
    else
        [blocks, tag_arrays, has_additional] = read_cells_binary(fid, total);
    end
    meshio.gmsh.common.fast_forward_to_end_block(fid, "Elements");

    if isempty(point_tags)
        remap = [];
    else
        remap = zeros(1, max(point_tags));
        remap(point_tags) = 1:numel(point_tags);
    end

    cells = meshio.CellBlock.empty(1, 0);
    tags_by_block = struct('physical', {{}}, 'geometrical', {{}});
    for i = 1:numel(blocks)
        t = blocks{i}{1};
        gmsh_tags = blocks{i}{2};
        if isempty(remap)
            data = gmsh_tags;
        else
            data = remap(gmsh_tags);
            if size(gmsh_tags, 1) == 1
                data = reshape(data, 1, []);
            end
        end
        data = meshio.gmsh.common.gmsh_to_meshio_order(t, data);
        cells(end+1) = meshio.CellBlock(t, data); %#ok<AGROW>
        tags_by_block.physical{end+1}    = tag_arrays{i}.physical;
        tags_by_block.geometrical{end+1} = tag_arrays{i}.geometrical;
    end
end


function [blocks, tag_arrays, has_additional] = read_cells_ascii(fid, total)
    gmsh_to_meshio = meshio.gmsh.common.gmsh_to_meshio_type();
    nnpc = meshio.internal.num_nodes_per_cell();
    blocks = {};
    tag_arrays = {};
    has_additional = false;
    last_type = "";
    block_rows = {};
    block_phys = [];
    block_geom = [];
    for k = 1:total
        parts = sscanf(fgetl(fid), '%d')';
        gmsh_type = parts(2);
        % data[2] gives the number of tags. The gmsh manual
        % <http://gmsh.info/doc/texinfo/gmsh.html#MSH-ASCII-file-format>
        % says:
        % >>>
        % By default, the first tag is the number of the physical entity to which the
        % element belongs; the second is the number of the elementary geometrical entity
        % to which the element belongs; the third is the number of mesh partitions to
        % which the element belongs, followed by the partition ids (negative partition
        % ids indicate ghost cells). A zero tag is equivalent to no tag. Gmsh and most
        % codes using the MSH 2 format require at least the first two tags (physical and
        % elementary tags).
        % <<<
        num_tags = parts(3);
        if num_tags > 2
            has_additional = true;
        end
        t = gmsh_to_meshio(gmsh_type);
        npe = nnpc(t);
        nodes = parts(end - npe + 1 : end);
        phys = 0; geom = 0;
        if num_tags >= 1, phys = parts(4); end
        if num_tags >= 2, geom = parts(5); end
        if last_type == "" || t ~= last_type
            if ~isempty(block_rows)
                blocks{end+1} = {last_type, vertcat(block_rows{:})}; %#ok<AGROW>
                tag_arrays{end+1} = struct('physical', int32(block_phys(:)), ...
                                           'geometrical', int32(block_geom(:))); %#ok<AGROW>
            end
            last_type = t;
            block_rows = {nodes};
            block_phys = phys;
            block_geom = geom;
        else
            block_rows{end+1} = nodes; %#ok<AGROW>
            block_phys(end+1) = phys; %#ok<AGROW>
            block_geom(end+1) = geom; %#ok<AGROW>
        end
    end
    if ~isempty(block_rows)
        blocks{end+1} = {last_type, vertcat(block_rows{:})};
        tag_arrays{end+1} = struct('physical', int32(block_phys(:)), ...
                                   'geometrical', int32(block_geom(:)));
    end
end


function [blocks, tag_arrays, has_additional] = read_cells_binary(fid, total)
    gmsh_to_meshio = meshio.gmsh.common.gmsh_to_meshio_type();
    nnpc = meshio.internal.num_nodes_per_cell();
    blocks = {};
    tag_arrays = {};
    has_additional = false;
    last_type = "";
    block_rows = {};
    block_phys = [];
    block_geom = [];
    consumed = 0;
    while consumed < total
        % read element header
        header = double(fread(fid, 3, 'int32=>int32'));
        elem_type = header(1);
        n_in_block = header(2);
        n_tags = header(3);
        if n_tags > 2, has_additional = true; end
        t = gmsh_to_meshio(elem_type);
        npe = nnpc(t);
        per_rec = 1 + n_tags + npe;
        % read element data
        raw = double(fread(fid, n_in_block * per_rec, 'int32=>int32'));
        recs = reshape(raw, per_rec, n_in_block)';
        nodes_block = recs(:, end - npe + 1 : end);
        phys = zeros(n_in_block, 1);
        geom = zeros(n_in_block, 1);
        if n_tags >= 1, phys = recs(:, 2); end
        if n_tags >= 2, geom = recs(:, 3); end
        if last_type == "" || t ~= last_type
            if ~isempty(block_rows)
                blocks{end+1} = {last_type, vertcat(block_rows{:})}; %#ok<AGROW>
                tag_arrays{end+1} = struct('physical', int32(block_phys), ...
                                           'geometrical', int32(block_geom)); %#ok<AGROW>
            end
            last_type = t;
            block_rows = {nodes_block};
            block_phys = phys;
            block_geom = geom;
        else
            block_rows{end+1} = nodes_block; %#ok<AGROW>
            block_phys = [block_phys; phys]; %#ok<AGROW>
            block_geom = [block_geom; geom]; %#ok<AGROW>
        end
        consumed = consumed + n_in_block;
    end
    if ~isempty(block_rows)
        blocks{end+1} = {last_type, vertcat(block_rows{:})};
        tag_arrays{end+1} = struct('physical', int32(block_phys), ...
                                   'geometrical', int32(block_geom));
    end
end
