function mesh = tri_quad_mesh()
% TRI_QUAD_MESH  Fixture mirroring helpers.tri_quad_mesh (1-based indices).
    pts = [0 0 0; 1 0 0; 2 0 0; 3 1 0; 2 1 0; 1 1 0; 0 1 0];
    cells = {
        {"triangle", [1 2 6; 1 6 7]}, ...
        {"quad",     [2 3 5 6]}, ...
        {"triangle", [3 4 5]}
    };
    mesh = meshio.Mesh(pts, cells);
end
