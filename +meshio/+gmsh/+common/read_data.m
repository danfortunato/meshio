function data_dict = read_data(fid, tag, data_dict, data_size, is_ascii)
% READ_DATA  Read a $NodeData or $ElementData block.
%   Mirrors meshio.gmsh.common._read_data.
    arguments
        fid
        tag       (1,1) string
        data_dict (1,1) dictionary
        data_size (1,1) double %#ok<INUSA>
        is_ascii  (1,1) logical
    end

    % string tags
    num_string_tags = sscanf(fgetl(fid), '%d');
    string_tags = strings(1, num_string_tags);
    for k = 1:num_string_tags
        raw = strtrim(fgetl(fid));
        string_tags(k) = string(strrep(raw, '"', ''));
    end
    % real tags (typically time -- discard)
    num_real_tags = sscanf(fgetl(fid), '%d');
    for k = 1:num_real_tags
        fgetl(fid);
    end
    % integer tags
    num_integer_tags = sscanf(fgetl(fid), '%d');
    integer_tags = zeros(1, num_integer_tags);
    for k = 1:num_integer_tags
        integer_tags(k) = sscanf(fgetl(fid), '%d');
    end
    num_components = integer_tags(2);
    num_items = integer_tags(3);

    if is_ascii
        raw = fscanf(fid, '%f', [1 + num_components, num_items])';
        % The first entry is the node number
        data = raw(:, 2:end);
    else
        % binary
        data = zeros(num_items, num_components);
        for k = 1:num_items
            fread(fid, 1, 'int32=>int32');
            data(k, :) = fread(fid, num_components, 'double=>double')';
        end
    end

    meshio.gmsh.common.fast_forward_to_end_block(fid, tag);

    % The gmsh format cannot distinguish between data of shape (n,) and (n, 1).
    % If shape[1] == 1, cut it off.
    if size(data, 2) == 1
        data = data(:);
    end
    data_dict{string_tags(1)} = data;
end
