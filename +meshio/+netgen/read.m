function mesh = read(filename)
% READ  I/O for Netgen mesh files.
%   <https://github.com/NGSolve/netgen/blob/master/libsrc/meshing/meshclass.cpp>
    if endsWith(string(filename), ".vol.gz")
        tmp_cell = gunzip(char(filename), tempdir);
        tmp = tmp_cell{1};
        cleanup_tmp = onCleanup(@() delete(tmp)); %#ok<NASGU>
        mesh = read_buffer(tmp);
        return
    end
    mesh = read_buffer(filename);
end


function mesh = read_buffer(filename)
    fid = fopen(filename, 'r');
    if fid < 0
        error("meshio:ReadError", "Cannot open '%s'.", filename);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    points = zeros(0, 3);
    cells_blocks = {};   % each: {meshio_type, NxK indices}
    cells_index  = {};   % parallel: cell array of column vectors of int indices
    field_data   = configureDictionary("string", "cell");
    identifications = [];
    identificationtypes = [];

    have_edgesegmentsgi2_in_two_lines = false;
    netgen_codims = configureDictionary("string", "double");
    netgen_codims("materials") = 0;
    netgen_codims("bcnames")   = 1;
    netgen_codims("cd2names")  = 2;
    netgen_codims("cd3names")  = 3;

    [line, is_eof] = next_line(fid);
    if line ~= "mesh3d"
        error("meshio:ReadError", "Not a valid Netgen mesh");
    end

    dimension = 3;
    while true
        [line, is_eof] = next_line(fid);
        if is_eof, break, end

        if line == "dimension"
            dimension = sscanf(fgetl(fid), '%d');
        elseif line == "geomtype"
            geomtype = sscanf(fgetl(fid), '%d');
            if ~ismember(geomtype, [0, 1, 10, 11, 12, 13])
                warning("meshio:netgen:unknownGeomtype", ...
                    "Unknown geomtype in Netgen mesh: %d", geomtype);
            end
        elseif line == "points"
            num_points = sscanf(fgetl(fid), '%d');
            if num_points > 0
                points = zeros(num_points, 3);
                for k = 1:num_points
                    points(k, :) = sscanf(fgetl(fid), '%f')';
                end
                if dimension ~= 3
                    points = points(:, 1:dimension);
                end
            end
        elseif ismember(line, ["pointelements", "edgesegments", "edgesegmentsgi", ...
                "edgesegmentsgi2", "surfaceelements", "surfaceelementsgi", ...
                "surfaceelementsuv", "volumeelements"])
            [cells_blocks, cells_index] = read_cells(fid, line, ...
                cells_blocks, cells_index, have_edgesegmentsgi2_in_two_lines);
        elseif line == "endmesh"
            break
        elseif strjoin(strsplit(line)) == "surf1 surf2 p1 p2"
            % if this line is present, the edgesegmentsgi2 info is split in two
            % lines per data set
            have_edgesegmentsgi2_in_two_lines = true;
        elseif isKey(netgen_codims, line)
            edim = dimension - netgen_codims(line);
            num_entries = sscanf(fgetl(fid), '%d');
            for k = 1:num_entries
                row = strtrim(fgetl(fid));
                parts = regexp(row, '\s+', 'split');
                if numel(parts) ~= 2
                    continue
                end
                idx  = str2double(parts{1});
                name = string(parts{2});
                field_data{name} = [idx, edim];
            end
        elseif line == "identifications"
            num_entries = sscanf(fgetl(fid), '%d');
            if num_entries > 0
                identifications = zeros(num_entries, 3);
                for k = 1:num_entries
                    identifications(k, :) = sscanf(fgetl(fid), '%d')';
                end
            end
        elseif line == "identificationtypes"
            num_entries = sscanf(fgetl(fid), '%d');
            if num_entries > 0
                identificationtypes = sscanf(fgetl(fid), '%d', [1, num_entries]);
            end
        elseif ismember(line, ["face_colours", "singular_edge_left", ...
                "singular_edge_right", "singular_face_inside", ...
                "singular_face_outside", "singular_points"])
            skip_block(fid);
        else
            error("meshio:ReadError", "Unknown Netgen mesh token: %s", line);
        end
    end

    % Convert: apply permutation of vertex numbers (netgen -> meshio order).
    % Netgen indices on file are 1-based -- same as MATLAB, no subtraction needed.
    pmap_table = meshio.netgen.common.netgen_to_meshio_pmap();
    cells = meshio.CellBlock.empty(1, 0);
    cells_index_list = {};
    for k = 1:numel(cells_blocks)
        t = cells_blocks{k}{1};
        d = cells_blocks{k}{2};
        pmap = pmap_table{t};
        d = d(:, pmap);
        cells(end+1) = meshio.CellBlock(t, d); %#ok<AGROW>
        cells_index_list{end+1} = cells_index{k}; %#ok<AGROW>
    end

    cell_data = configureDictionary("string", "cell");
    cell_data{"netgen:index"} = cells_index_list;

    info = configureDictionary("string", "cell");
    if ~isempty(identifications)
        info{"netgen:identifications"}     = identifications;
        info{"netgen:identificationtypes"} = identificationtypes;
    end

    mesh = meshio.Mesh(points, cells, ...
        cell_data  = cell_data, ...
        field_data = field_data, ...
        info       = info);
end


function [cells_blocks, cells_index] = read_cells(fid, netgen_cell_type, ...
        cells_blocks, cells_index, skip_every_other_line)
    if netgen_cell_type == "pointelements"
        dim = 0; nump = 1; pi0 = 1; i_index = 2;
    elseif startsWith(netgen_cell_type, "edgesegments")
        dim = 1; nump = 2; pi0 = 3; i_index = 1;
    elseif startsWith(netgen_cell_type, "surfaceelements")
        dim = 2; nump = -1; pi0 = 6; i_index = 2;
    elseif netgen_cell_type == "volumeelements"
        dim = 3; nump = -1; pi0 = 3; i_index = 1;
    else
        error("meshio:ReadError", "Unknown Netgen cell section '%s'", netgen_cell_type);
    end

    num_cells = sscanf(fgetl(fid), '%d');
    for k = 1:num_cells
        [line, ~] = next_line(fid);
        data = sscanf(line, '%d')';
        index = data(i_index);
        if dim == 2
            nump = data(5);
        elseif dim == 3
            nump = data(2);
        end
        pi = data(pi0 : pi0 + nump - 1);
        t = meshio.netgen.common.netgen_to_meshio_type(dim, nump);

        if isempty(cells_blocks) || t ~= cells_blocks{end}{1}
            cells_blocks{end+1} = {t, zeros(0, nump)}; %#ok<AGROW>
            cells_index{end+1}  = zeros(0, 1, 'int32'); %#ok<AGROW>
        end
        cells_blocks{end}{2}(end+1, :) = pi;
        cells_index{end}(end+1, 1)     = int32(index);
        if skip_every_other_line
            next_line(fid);
        end
    end
end


function skip_block(fid)
    n = sscanf(fgetl(fid), '%d');
    for k = 1:n
        fgetl(fid);
    end
end


function [line, is_eof] = next_line(fid)
    is_eof = false;
    while true
        raw = fgetl(fid);
        if ~ischar(raw)
            line = ''; is_eof = true; return
        end
        line = strtrim(string(raw));
        if line ~= "" && extractBefore(line + " ", 2) ~= "#"
            return
        end
    end
end
