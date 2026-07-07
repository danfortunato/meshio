function write(filename, mesh, options)
% WRITE  Write a Gmsh msh file.
%   Mirrors meshio.gmsh.main.write.
%   Gmsh ASCII output uses `%.16g` for floating point values, meshio uses
%   same precision but exponential notation `%.16e`.
    arguments
        filename
        mesh                (1,1) meshio.Mesh
        options.fmt_version (1,1) string      = "4.1"
        options.binary      (1,1) logical     = true
        options.float_fmt   (1,1) string      = ".16e"
    end
    switch options.fmt_version
        case "2.2"
            meshio.gmsh.v22.write(filename, mesh, ...
                binary    = options.binary, ...
                float_fmt = options.float_fmt);
        case "4.0"
            meshio.gmsh.v40.write(filename, mesh, ...
                binary    = options.binary, ...
                float_fmt = options.float_fmt);
        case "4.1"
            meshio.gmsh.v41.write(filename, mesh, ...
                binary    = options.binary, ...
                float_fmt = options.float_fmt);
        otherwise
            error("meshio:WriteError", ...
                "Need mesh format in {2.2, 4.0, 4.1} (got %s)", options.fmt_version);
    end
end
