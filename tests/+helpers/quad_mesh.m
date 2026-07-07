function mesh = quad_mesh()
% QUAD_MESH  Fixture mirroring helpers.quad_mesh (1-based indices).
    pts = [0 0 0; 1 0 0; 2 0 0; 2 1 0; 1 1 0; 0 1 0];
    cells = {{"quad", [1 2 5 6; 2 3 4 5]}};
    mesh = meshio.Mesh(pts, cells);
end
