function t = netgen_to_meshio_type(dim, nump)
% NETGEN_TO_MESHIO_TYPE  Map (dim, num_points) -> meshio cell type name.
%   Mirrors meshio.netgen._netgen.netgen_to_meshio_type.
    persistent tables
    if isempty(tables)
        tables = cell(1, 4);
        tables{1} = dictionary(1, "vertex");
        tables{2} = dictionary(2, "line");
        tables{3} = dictionary(3, "triangle", 6, "triangle6", 4, "quad", 8, "quad8");
        tables{4} = dictionary( ...
            4,  "tetra",       5,  "pyramid",     6,  "wedge",       8,  "hexahedron", ...
            10, "tetra10",     13, "pyramid13",   15, "wedge15",     20, "hexahedron20");
    end
    t = tables{dim + 1}(nump);
end
