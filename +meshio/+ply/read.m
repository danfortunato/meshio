function mesh = read(filename)
% READ  Read a PLY mesh. Mirrors meshio.ply._ply.read.
%   PLY indices are 0-based on file; converted to 1-based here.
    fid = fopen(filename, 'r');
    if fid < 0
        error("meshio:ReadError", "Cannot open '%s'.", filename);
    end

    % --- parse header ---
    line = strtrim(string(fgetl(fid)));
    if line ~= "ply"
        fclose(fid);
        error("meshio:ReadError", "Expected ply");
    end

    line = next_line(fid);
    endianness = "";
    if line == "format ascii 1.0"
        is_binary = false;
    elseif line == "format binary_big_endian 1.0"
        is_binary = true;
        endianness = "b";
    elseif line == "format binary_little_endian 1.0"
        is_binary = true;
        endianness = "l";
    else
        fclose(fid);
        error("meshio:ReadError", "Unsupported format line: '%s'", line);
    end

    line = next_line(fid);
    num_verts = 0;
    num_cells = 0;
    point_data_formats = strings(0);
    point_data_names   = strings(0);
    cell_data_names    = strings(0);
    cell_data_dtypes   = {};
    while line ~= "end_header"
        m_vert = regexp(line, '^element vertex (\d+)$', 'tokens', 'once');
        m_face = regexp(line, '^element face (\d+)$',   'tokens', 'once');
        if startsWith(line, "obj_info")
            line = next_line(fid);
        elseif ~isempty(m_vert)
            num_verts = str2double(m_vert{1});
            line = next_line(fid);
            while startsWith(line, "property")
                m = regexp(line, '^property (\S+) (\S+)$', 'tokens', 'once');
                point_data_formats(end+1) = string(m{1}); %#ok<AGROW>
                point_data_names(end+1)   = string(m{2}); %#ok<AGROW>
                line = next_line(fid);
            end
        elseif ~isempty(m_face)
            num_cells = str2double(m_face{1});
            if num_cells < 0
                fclose(fid);
                error("meshio:ReadError", "Expected positive num_cells (got `%d`.", num_cells);
            end
            line = next_line(fid);
            while startsWith(line, "property")
                if startsWith(line, "property list")
                    m = regexp(line, '^property list (\S+) (\S+) (\S+)$', 'tokens', 'once');
                    cell_data_dtypes{end+1} = {string(m{1}), string(m{2})}; %#ok<AGROW>
                    cell_data_names(end+1)  = string(m{3}); %#ok<AGROW>
                else
                    m = regexp(line, '^property (\S+) (\S+)$', 'tokens', 'once');
                    cell_data_dtypes{end+1} = string(m{1}); %#ok<AGROW>
                    cell_data_names(end+1)  = string(m{2}); %#ok<AGROW>
                end
                line = next_line(fid);
            end
        else
            fclose(fid);
            error("meshio:ReadError", ...
                "Expected `element vertex` or `element face` or `obj_info`, got `%s`", line);
        end
    end

    if is_binary
        header_end = ftell(fid);
        fclose(fid);
        fid = fopen(filename, 'r', endianness);
        fseek(fid, header_end, 'bof');
        cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
        mesh = read_binary(fid, point_data_names, point_data_formats, ...
            num_verts, num_cells, cell_data_names, cell_data_dtypes);
    else
        cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
        mesh = read_ascii(fid, point_data_names, point_data_formats, ...
            num_verts, num_cells, cell_data_names, cell_data_dtypes);
    end
end


function line = next_line(fid)
% Read the next non-empty, non-comment line.
    while true
        raw = fgetl(fid);
        if ~ischar(raw)
            error("meshio:ReadError", "Unexpected EOF in PLY header.");
        end
        line = strtrim(string(raw));
        if line ~= "" && extractBefore(line + " ", 8) ~= "comment"
            break
        end
    end
end


function mesh = read_ascii(fid, point_data_names, point_data_formats, ...
        num_verts, num_cells, cell_data_names, cell_data_dtypes)
    % Read vertex section line by line (textscan can leave the file mid-line).
    nprops = numel(point_data_names);
    raw_cols = zeros(num_verts, nprops);
    for v = 1:num_verts
        raw_line = strtrim(fgetl(fid));
        toks = regexp(raw_line, '\s+', 'split');
        for i = 1:nprops
            raw_cols(v, i) = str2double(toks{i});
        end
    end

    pd_columns = configureDictionary("string", "cell");
    for i = 1:nprops
        pd_columns{point_data_names(i)} = cast_ply(raw_cols(:, i), point_data_formats(i));
    end

    % Split off x/y/z; the rest becomes point_data.
    verts_cols = {};
    point_data = configureDictionary("string", "cell");
    k = 0;
    xyz_names = ["x", "y", "z"];
    for d = 1:3
        if nprops >= d && point_data_names(d) == xyz_names(d)
            verts_cols{end+1} = double(pd_columns{point_data_names(d)}); %#ok<AGROW>
            k = k + 1;
        end
    end
    for i = (k+1):nprops
        point_data{point_data_names(i)} = pd_columns{point_data_names(i)};
    end
    if isempty(verts_cols)
        verts = zeros(num_verts, 0);
    else
        verts = horzcat(verts_cols{:});
    end

    % Face section: read each face line.
    [cells, cell_data] = read_face_lines_ascii(fid, num_cells, ...
        cell_data_names, cell_data_dtypes);

    mesh = meshio.Mesh(verts, cells, ...
        point_data = point_data, cell_data = cell_data);
end


function [cells, cell_data] = read_face_lines_ascii(fid, num_cells, names, dtypes)
    blocks = {};        % each entry: {n, list-of-row-vectors, list-of-indices-into-cell_data}
    extra  = configureDictionary("string", "cell");   % per-name: list of values, one per face
    has_extra = false(1, numel(names));
    for i = 1:numel(names)
        if names(i) ~= "vertex_indices"
            extra{names(i)} = {};
            has_extra(i) = true;
        end
    end

    block_n = -1;
    block_rows = {};

    for k = 1:num_cells
        raw = fgetl(fid);
        toks = regexp(strtrim(raw), '\s+', 'split');
        i = 1;
        n = NaN;
        for p = 1:numel(names)
            dt = dtypes{p};
            if names(p) == "vertex_indices"
                n = str2double(toks{i});
                idx = str2double(toks(i+1:i+n)) + 1;   % 0-based -> 1-based
                if n ~= block_n
                    if ~isempty(block_rows)
                        blocks{end+1} = {block_n, vertcat(block_rows{:})}; %#ok<AGROW>
                    end
                    block_n = n;
                    block_rows = {idx};
                else
                    block_rows{end+1} = idx; %#ok<AGROW>
                end
                i = i + n + 1;
            else
                v = cast_ply(str2double(toks{i}), dt);
                extra{names(p)}{end+1} = v; %#ok<NASGU>
                i = i + 1;
            end
        end
    end
    if ~isempty(block_rows)
        blocks{end+1} = {block_n, vertcat(block_rows{:})};
    end

    cells = build_cell_blocks(blocks);
    cell_data = configureDictionary("string", "cell");
    for p = 1:numel(names)
        if has_extra(p)
            vals = extra{names(p)};
            cell_data{names(p)} = {vertcat(vals{:})};
        end
    end
end


function mesh = read_binary(fid, point_data_names, formats, ...
        num_verts, num_cells, cell_data_names, cell_data_dtypes)
    % Compute per-property sizes, total record size.
    nprops = numel(point_data_names);
    type_strs = strings(1, nprops);
    sizes = zeros(1, nprops);
    for i = 1:nprops
        type_strs(i) = ply_to_matlab_type(formats(i));
        sizes(i) = type_byte_size(type_strs(i));
    end
    record_size = sum(sizes);
    section_start = ftell(fid);
    offsets = [0, cumsum(sizes(1:end-1))];

    pd_columns = configureDictionary("string", "cell");
    for i = 1:nprops
        fseek(fid, section_start + offsets(i), 'bof');
        precision = sprintf('%s=>%s', type_strs(i), type_strs(i));
        skip = record_size - sizes(i);
        col = fread(fid, num_verts, precision, skip);
        pd_columns{point_data_names(i)} = col;
    end
    fseek(fid, section_start + num_verts * record_size, 'bof');

    % Split off x/y/z.
    verts_cols = {};
    point_data = configureDictionary("string", "cell");
    k = 0;
    xyz_names = ["x", "y", "z"];
    for d = 1:3
        if nprops >= d && point_data_names(d) == xyz_names(d)
            verts_cols{end+1} = double(pd_columns{point_data_names(d)}); %#ok<AGROW>
            k = k + 1;
        end
    end
    for i = (k+1):nprops
        point_data{point_data_names(i)} = pd_columns{point_data_names(i)};
    end
    if isempty(verts_cols)
        verts = zeros(num_verts, 0);
    else
        verts = horzcat(verts_cols{:});
    end

    % Face section: walk records.
    [cells, cell_data] = read_face_records_binary(fid, num_cells, ...
        cell_data_names, cell_data_dtypes);

    mesh = meshio.Mesh(verts, cells, ...
        point_data = point_data, cell_data = cell_data);
end


function [cells, cell_data] = read_face_records_binary(fid, num_cells, names, dtypes)
    extra = configureDictionary("string", "cell");
    has_extra = false(1, numel(names));
    for i = 1:numel(names)
        if names(i) ~= "vertex_indices"
            extra{names(i)} = {};
            has_extra(i) = true;
        end
    end

    blocks = {};
    block_n = -1;
    block_rows = {};

    for k = 1:num_cells
        for p = 1:numel(names)
            dt = dtypes{p};
            if names(p) == "vertex_indices"
                count_type = ply_to_matlab_type(dt{1});
                data_type  = ply_to_matlab_type(dt{2});
                n = double(fread(fid, 1, sprintf('%s=>%s', count_type, count_type)));
                idx = double(fread(fid, n, sprintf('%s=>%s', data_type, data_type)))' + 1;
                if n ~= block_n
                    if ~isempty(block_rows)
                        blocks{end+1} = {block_n, vertcat(block_rows{:})}; %#ok<AGROW>
                    end
                    block_n = n;
                    block_rows = {idx};
                else
                    block_rows{end+1} = idx; %#ok<AGROW>
                end
            else
                t = ply_to_matlab_type(dt);
                v = fread(fid, 1, sprintf('%s=>%s', t, t));
                extra{names(p)}{end+1} = v; %#ok<NASGU>
            end
        end
    end
    if ~isempty(block_rows)
        blocks{end+1} = {block_n, vertcat(block_rows{:})};
    end

    cells = build_cell_blocks(blocks);
    cell_data = configureDictionary("string", "cell");
    for p = 1:numel(names)
        if has_extra(p)
            vals = extra{names(p)};
            cell_data{names(p)} = {vertcat(vals{:})};
        end
    end
end


function cells = build_cell_blocks(blocks)
    cells = meshio.CellBlock.empty(1, 0);
    for k = 1:numel(blocks)
        n = blocks{k}{1};
        data = blocks{k}{2};
        cells(end+1) = meshio.CellBlock(meshio.ply.cell_type_from_count(n), data); %#ok<AGROW>
    end
end


function out = cast_ply(values, ply_fmt)
    matlab_type = ply_to_matlab_type(ply_fmt);
    out = cast(values, matlab_type);
end


function t = ply_to_matlab_type(ply_fmt)
    switch ply_fmt
        case {"char", "int8"},    t = "int8";
        case {"uchar", "uint8"},  t = "uint8";
        case {"short", "int16"},  t = "int16";
        case {"ushort", "uint16"},t = "uint16";
        case {"int", "int32"},    t = "int32";
        case {"uint", "uint32"},  t = "uint32";
        case "int64",             t = "int64";
        case "uint64",            t = "uint64";
        case {"float", "float32"},t = "single";
        case {"double", "float64"}, t = "double";
        otherwise
            error("meshio:ReadError", "Unknown PLY type '%s'.", ply_fmt);
    end
end


function n = type_byte_size(matlab_type)
    switch matlab_type
        case {"int8", "uint8"},   n = 1;
        case {"int16", "uint16"}, n = 2;
        case {"int32", "uint32"}, n = 4;
        case "single",            n = 4;
        case {"int64", "uint64"}, n = 8;
        case "double",            n = 8;
        otherwise
            error("meshio:ReadError", "Unknown MATLAB type '%s'.", matlab_type);
    end
end
