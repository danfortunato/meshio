function field_data = read_physical_names(fid, field_data)
% READ_PHYSICAL_NAMES  Read a $PhysicalNames block.
%   Mirrors meshio.gmsh.common._read_physical_names.
%   field_data : dictionary mapping name -> [tag, dim] (length-2 int vector)
    num = sscanf(fgetl(fid), '%d');
    for k = 1:num
        raw = strtrim(fgetl(fid));
        % line format: <dim> <tag> "<name>"
        m = regexp(raw, '^(\d+)\s+(\d+)\s+"(.*)"$', 'tokens', 'once');
        if isempty(m)
            error("meshio:ReadError", "Bad $PhysicalNames line: '%s'", raw);
        end
        dim = str2double(m{1});
        tag = str2double(m{2});
        name = string(m{3});
        field_data{name} = int32([tag, dim]);
    end
    meshio.gmsh.common.fast_forward_to_end_block(fid, "PhysicalNames");
end
