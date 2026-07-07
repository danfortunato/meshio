function write(filename, mesh, file_format, varargin)
% WRITE  Write a mesh to a file. Mirrors meshio._helpers.write.
%
%   meshio.write(filename, mesh)
%   meshio.write(filename, mesh, file_format)
%   meshio.write(filename, mesh, file_format, Name, Value, ...)
%
%   filename    : path string OR numeric file ID from fopen
%   mesh        : meshio.Mesh
%   file_format : optional explicit format name; deduced from extension if omitted
%   varargin    : forwarded to the underlying writer
    arguments
        filename
        mesh (1,1) meshio.Mesh
        file_format = []
    end
    arguments (Repeating)
        varargin
    end
    if isempty(file_format)
        file_format = "";
    else
        file_format = string(file_format);
    end

    if meshio.internal.is_buffer(filename, "w")
        if file_format == ""
            error("meshio:WriteError", ...
                "File format must be supplied if filename is a file ID.");
        end
        if file_format == "tetgen"
            error("meshio:WriteError", ...
                "tetgen format is spread across multiple files and cannot be written to a buffer.");
        end
    else
        if file_format == ""
            candidates = meshio.internal.filetypes_from_path(filename);
            file_format = candidates(1);
        end
    end

    % cell-block shape sanity check (mirrors _helpers.write)
    nnpc = meshio.internal.num_nodes_per_cell();
    for i = 1:numel(mesh.cells)
        cb = mesh.cells(i);
        if isKey(nnpc, cb.type)
            if iscell(cb.data)
                continue  % polyhedron; skip shape check
            end
            if size(cb.data, 2) ~= nnpc(cb.type)
                error("meshio:WriteError", ...
                    "Unexpected cells array shape [%d, %d] for %s cells. Expected [:, %d].", ...
                    size(cb.data,1), size(cb.data,2), cb.type, nnpc(cb.type));
            end
        end
    end

    dispatch_write(file_format, filename, mesh, varargin{:});
end

function dispatch_write(fmt, filename, mesh, varargin)
    switch fmt
        case "off",  meshio.off.write(filename, mesh, varargin{:});
        case "obj",  meshio.obj.write(filename, mesh, varargin{:});
        case "stl",  meshio.stl.write(filename, mesh, varargin{:});
        case "ply",  meshio.ply.write(filename, mesh, varargin{:});
        case "gmsh", meshio.gmsh.write(filename, mesh, varargin{:});
        case "tetgen", meshio.tetgen.write(filename, mesh, varargin{:});
        case "netgen", meshio.netgen.write(filename, mesh, varargin{:});
        otherwise
            error("meshio:WriteError", "Unknown file format '%s'.", fmt);
    end
end
