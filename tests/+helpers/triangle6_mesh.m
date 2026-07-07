function mesh = triangle6_mesh()
% TRIANGLE6_MESH  Fixture mirroring helpers.triangle6_mesh (1-based).
    pts = [
        0    0    0
        1    0    0
        1    1    0
        0.5  0.25 0
        1.25 0.5  0
        0.25 0.75 0
        2    1    0
        1.5  1.25 0
        1.75 0.25 0
    ];
    cells = {{"triangle6", [1 2 3 4 5 6; 2 7 3 9 8 5]}};
    mesh = meshio.Mesh(pts, cells);
end
