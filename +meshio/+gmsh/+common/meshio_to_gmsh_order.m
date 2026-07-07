function out = meshio_to_gmsh_order(cell_type, idx)
% MESHIO_TO_GMSH_ORDER  Reorder meshio (VTK-like) node indices into gmsh order.
%   Mirrors meshio.gmsh.common._meshio_to_gmsh_order.
%   Indices below are 1-based (Python source uses 0-based).
    % Gmsh cells are mostly ordered like VTK, with a few exceptions:
    persistent ordering
    if isempty(ordering)
        ordering = configureDictionary("string", "cell");
        ordering{"tetra10"}      = [1 2 3 4 5 6 7 8 10 9];
        ordering{"hexahedron20"} = [1 2 3 4 5 6 7 8 9 12 17 10 18 11 19 20 13 16 14 15];
        ordering{"hexahedron27"} = [1 2 3 4 5 6 7 8 9 12 17 10 18 11 19 20 13 16 14 15, ...
                                    25 23 21 22 24 26 27];
        ordering{"wedge15"}      = [1 2 3 4 5 6 7 9 13 8 14 15 10 12 11];
        ordering{"pyramid13"}    = [1 2 3 4 5 6 9 10 7 11 8 12 13];
    end
    if ~isKey(ordering, cell_type)
        out = idx;
        return
    end
    out = idx(:, ordering{cell_type});
end
