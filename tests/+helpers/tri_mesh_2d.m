function mesh = tri_mesh_2d()
% TRI_MESH_2D  Fixture mirroring helpers.tri_mesh_2d (2D points, 1-based).
    pts = [0 0; 1 0; 1 1; 0 1];
    cells = {{"triangle", [1 2 3; 1 3 4]}};
    mesh = meshio.Mesh(pts, cells);
end
