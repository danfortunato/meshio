function d = meshio_to_gmsh_type()
% MESHIO_TO_GMSH_TYPE  Inverse of gmsh_to_meshio_type.
    persistent cache
    if isempty(cache)
        m = meshio.gmsh.common.gmsh_to_meshio_type();
        cache = dictionary(values(m), keys(m));
    end
    d = cache;
end
