function write_physical_names(fid, field_data)
% WRITE_PHYSICAL_NAMES  Write a $PhysicalNames block.
%   Mirrors meshio.gmsh.common._write_physical_names.
%   field_data : dictionary mapping name -> [tag, dim]
    % Write physical names
    entries = {};
    ks = keys(field_data);
    for i = 1:numel(ks)
        v = field_data{ks(i)};
        if numel(v) < 2
            warning("meshio:gmsh:badFieldData", ...
                "Field data contains entry that cannot be processed.");
            continue
        end
        phys_num = double(v(1));
        phys_dim = double(v(2));
        entries{end+1} = {phys_dim, phys_num, ks(i)}; %#ok<AGROW>
    end
    if isempty(entries)
        return
    end
    % Sort lexicographically by (phys_dim, phys_num, phys_name).
    nE = numel(entries);
    keystr = strings(1, nE);
    for i = 1:nE
        keystr(i) = sprintf("%010d|%010d|%s", entries{i}{1}, entries{i}{2}, entries{i}{3});
    end
    [~, order] = sort(keystr);
    entries = entries(order);

    fprintf(fid, "$PhysicalNames\n%d\n", nE);
    for i = 1:nE
        fprintf(fid, '%d %d "%s"\n', entries{i}{1}, entries{i}{2}, entries{i}{3});
    end
    fprintf(fid, "$EndPhysicalNames\n");
end
