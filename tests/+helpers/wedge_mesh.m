function mesh = wedge_mesh()
% WEDGE_MESH  Fixture mirroring helpers.wedge_mesh (1-based).
    pts = [
        0 0 0
        1 0 0
        1 1 0
        0 0 1
        1 0 1
        1 1 1
    ];
    cells = {{"wedge", [1 2 3 4 5 6]}};
    mesh = meshio.Mesh(pts, cells);
end
