function mesh = tet_mesh()
% TET_MESH  Fixture mirroring helpers.tet_mesh (1-based).
    pts = [0 0 0; 1 0 0; 1 1 0; 0 1 0; 0.5 0.5 0.5];
    cells = {{"tetra", [1 2 3 5; 1 3 4 5]}};
    mesh = meshio.Mesh(pts, cells);
end
