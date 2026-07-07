function mesh = pyramid_mesh()
% PYRAMID_MESH  Fixture mirroring helpers.pyramid_mesh (1-based).
    pts = [
        0    0    0
        1    0    0
        1    1    0
        0    1    0
        0.5  0.5  1
    ];
    cells = {{"pyramid", [1 2 3 4 5]}};
    mesh = meshio.Mesh(pts, cells);
end
