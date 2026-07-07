function mesh = read(filename, file_format)
% READ  Read a mesh from a file. Mirrors meshio._helpers.read.
%
%   mesh = meshio.read(filename)
%   mesh = meshio.read(filename, file_format)
%
%   filename     : path string OR numeric file ID from fopen
%   file_format  : optional explicit format name; deduced from extension if omitted
    arguments
        filename
        file_format = []
    end
    if isempty(file_format)
        file_format = "";
    else
        file_format = string(file_format);
    end

    if meshio.internal.is_buffer(filename, "r")
        if file_format == "" || ismissing(file_format)
            error("meshio:ReadError", ...
                "File format must be given if a file ID is used.");
        end
        if file_format == "tetgen"
            error("meshio:ReadError", ...
                "tetgen format is spread across multiple files and cannot be read from a buffer.");
        end
        mesh = dispatch_read(file_format, filename);
        return
    end

    if ~isfile(filename)
        error("meshio:ReadError", "File '%s' not found.", filename);
    end

    if file_format == ""
        candidates = meshio.internal.filetypes_from_path(filename);
    else
        candidates = file_format;
    end

    last_err = [];
    for i = 1:numel(candidates)
        try
            mesh = dispatch_read(candidates(i), char(filename));
            return
        catch ME
            last_err = ME;
            fprintf(2, '%s\n', ME.message);
        end
    end

    if numel(candidates) == 1
        msg = sprintf("Couldn't read file %s as %s", filename, candidates(1));
    else
        msg = sprintf("Couldn't read file %s as either of %s", ...
            filename, strjoin(candidates, ", "));
    end
    if isempty(last_err)
        error("meshio:ReadError", "%s", msg);
    else
        error("meshio:ReadError", "%s\nLast error: %s", msg, last_err.message);
    end
end

function mesh = dispatch_read(fmt, source)
    switch fmt
        case "off",  mesh = meshio.off.read(source);
        case "obj",  mesh = meshio.obj.read(source);
        case "stl",  mesh = meshio.stl.read(source);
        case "ply",  mesh = meshio.ply.read(source);
        case "gmsh", mesh = meshio.gmsh.read(source);
        case "tetgen", mesh = meshio.tetgen.read(source);
        case "netgen", mesh = meshio.netgen.read(source);
        otherwise
            error("meshio:ReadError", "Unknown file format '%s'.", fmt);
    end
end
