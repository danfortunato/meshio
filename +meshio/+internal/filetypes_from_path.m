function out = filetypes_from_path(path)
% FILETYPES_FROM_PATH  Deduce candidate file formats from a file path.
%   Returns a string array of candidate format names (the first is preferred).
%   Mirrors meshio._helpers._filetypes_from_path: tries progressively longer
%   compound suffixes (e.g. ".gz", then ".tar.gz") against the extension map.
%
%   Format additions: edit extension_to_filetypes below AND add a case to
%   the switch in meshio.read / meshio.write.
    persistent ext_map
    if isempty(ext_map)
        ext_map = configureDictionary("string", "cell");
        ext_map{".off"}  = "off";
        ext_map{".obj"}  = "obj";
        ext_map{".stl"}  = "stl";
        ext_map{".ply"}  = "ply";
        ext_map{".msh"}  = "gmsh";
        ext_map{".node"} = "tetgen";
        ext_map{".ele"}  = "tetgen";
        ext_map{".vol"}     = "netgen";
        ext_map{".vol.gz"}  = "netgen";
    end

    name = char(path);
    suffixes = {};
    while true
        [~, base, ext] = fileparts(name);
        if isempty(ext)
            break
        end
        suffixes{end+1} = lower(ext); %#ok<AGROW>
        name = base;
    end

    out = string([]);
    ext_acc = "";
    for i = 1:numel(suffixes)
        ext_acc = string(suffixes{i}) + ext_acc;
        if isKey(ext_map, ext_acc)
            out = [out, string(ext_map{ext_acc})]; %#ok<AGROW>
        end
    end

    if isempty(out)
        error("meshio:ReadError", ...
            "Could not deduce file format from path '%s'.", path);
    end
end
