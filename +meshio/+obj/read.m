function mesh = read(filename)
% READ  Read a Wavefront OBJ file. Mirrors meshio.obj._obj.read.
%   OBJ indices are 1-based on file -- same as MATLAB, so no conversion needed.
    fid = fopen(filename, 'r');
    if fid < 0
        error("meshio:ReadError", "Cannot open '%s'.", filename);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    pts_cells       = {};
    vn_cells        = {};
    vt_cells        = {};
    face_groups     = {};
    face_group_ids  = {};
    face_group_id   = -1;

    while true
        raw = fgetl(fid);
        if ~ischar(raw)
            break  % EOF
        end
        line = strtrim(raw);
        if isempty(line) || line(1) == '#'
            continue
        end
        parts = regexp(line, '\s+', 'split');
        switch parts{1}
            case 'v'
                pts_cells{end+1} = str2double(parts(2:end)); %#ok<AGROW>
            case 'vn'
                vn_cells{end+1}  = str2double(parts(2:end)); %#ok<AGROW>
            case 'vt'
                vt_cells{end+1}  = str2double(parts(2:end)); %#ok<AGROW>
            case 's'
                % "s 1" or "s off" controls smooth shading
            case 'f'
                tokens = parts(2:end);
                dat = zeros(1, numel(tokens));
                for i = 1:numel(tokens)
                    slash = strsplit(tokens{i}, '/');
                    dat(i) = sscanf(slash{1}, '%d');
                end
                if isempty(face_groups) || ...
                   (~isempty(face_groups{end}) && size(face_groups{end}, 2) ~= numel(dat))
                    face_groups{end+1}    = zeros(0, numel(dat)); %#ok<AGROW>
                    face_group_ids{end+1} = []; %#ok<AGROW>
                end
                face_groups{end}    = [face_groups{end}; dat];
                face_group_ids{end} = [face_group_ids{end}, face_group_id];
            case 'g'
                % new group
                face_groups{end+1}    = []; %#ok<AGROW>
                face_group_ids{end+1} = []; %#ok<AGROW>
                face_group_id = face_group_id + 1;
            otherwise
                % who knows
        end
    end

    % There may be empty groups, too. <https://github.com/nschloe/meshio/issues/770>
    % Remove them.
    nonempty = cellfun(@(g) ~isempty(g), face_groups);
    face_groups    = face_groups(nonempty);
    face_group_ids = face_group_ids(nonempty);

    points = vertcat(pts_cells{:});
    if isempty(points)
        points = zeros(0, 3);
    end

    point_data = configureDictionary("string", "cell");
    if ~isempty(vt_cells)
        point_data{"obj:vt"} = vertcat(vt_cells{:});
    end
    if ~isempty(vn_cells)
        point_data{"obj:vn"} = vertcat(vn_cells{:});
    end

    cells = meshio.CellBlock.empty(1, 0);
    group_ids_list = {};
    for k = 1:numel(face_groups)
        f = face_groups{k};
        switch size(f, 2)
            case 3
                cells(end+1) = meshio.CellBlock("triangle", f); %#ok<AGROW>
            case 4
                cells(end+1) = meshio.CellBlock("quad", f); %#ok<AGROW>
            otherwise
                cells(end+1) = meshio.CellBlock("polygon", f); %#ok<AGROW>
        end
        group_ids_list{end+1} = face_group_ids{k}(:); %#ok<AGROW>
    end

    cell_data = configureDictionary("string", "cell");
    cell_data{"obj:group_ids"} = group_ids_list;

    mesh = meshio.Mesh(points, cells, ...
        point_data = point_data, cell_data = cell_data);
end
