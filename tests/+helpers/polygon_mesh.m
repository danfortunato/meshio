function mesh = polygon_mesh()
% POLYGON_MESH  Fixture mirroring helpers.polygon_mesh (1-based indices).
    pts = [
        0    0    0
        1    0    0
        1    1    0
        0    1    0
        1.5  0    0
        1.7  0.5  0
        1.5  1.2  0
       -0.1  1.1  0
       -0.5  1.4  0
       -0.7  0.8  0
       -0.3 -0.1  0
    ];
    cells = {
        {"triangle", [1 2 3; 5 6 7]}, ...
        {"quad",     [1 2 3 4]}, ...
        {"polygon",  [2 5 6 7 3]}, ...
        {"polygon",  [1 4 8 9 10 11; 2 4 8 9 10 11]}
    };
    mesh = meshio.Mesh(pts, cells);
end
