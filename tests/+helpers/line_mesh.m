function mesh = line_mesh()
% LINE_MESH  Fixture mirroring helpers.line_mesh (1-based indices).
    pts = [0 0 0; 1 0 0; 1 1 0; 0 1 0];
    cells = {{"line", [1 2; 1 3; 1 4; 2 3; 3 4]}};
    mesh = meshio.Mesh(pts, cells);
end
