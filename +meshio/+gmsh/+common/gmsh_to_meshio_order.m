function out = gmsh_to_meshio_order(cell_type, idx)
% GMSH_TO_MESHIO_ORDER  Reorder gmsh node indices into meshio (VTK-like) order.
%   Mirrors meshio.gmsh.common._gmsh_to_meshio_order.
%   Indices below are 1-based (Python source uses 0-based).
    % Gmsh cells are mostly ordered like VTK, with a few exceptions:
    persistent ordering
    if isempty(ordering)
        ordering = configureDictionary("string", "cell");
        ordering{"tetra10"}      = [1 2 3 4 5 6 7 8 10 9];
        % https://vtk.org/doc/release/4.2/html/classvtkQuadraticHexahedron.html
        % and https://gmsh.info/doc/texinfo/gmsh.html#Node-ordering
        ordering{"hexahedron20"} = [1 2 3 4 5 6 7 8 9 12 14 10 17 19 20 18 11 13 15 16];
        ordering{"hexahedron27"} = [1 2 3 4 5 6 7 8 9 12 14 10 17 19 20 18 11 13 15 16, ...
                                    23 24 22 25 21 26 27];
        % http://davis.lbl.gov/Manuals/VTK-4.5/classvtkQuadraticWedge.html
        % and https://gmsh.info/doc/texinfo/gmsh.html#Node-ordering
        ordering{"wedge15"}      = [1 2 3 4 5 6 7 10 8 13 15 14 9 11 12];
        ordering{"pyramid13"}    = [1 2 3 4 5 6 9 11 7 8 10 12 13];
    end
    if ~isKey(ordering, cell_type)
        out = idx;
        return
    end
    out = idx(:, ordering{cell_type});
end
