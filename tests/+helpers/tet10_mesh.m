function mesh = tet10_mesh()
% TET10_MESH  Fixture mirroring helpers.tet10_mesh (1-based).
    pts = [
        0    0    0
        1    0    0
        1    1    0
        0.5  0.5  0.5
        %
        0.5  0    0.1
        1    0.5  0.1
        0.5  0.5  0.1
        0.25 0.3  0.25
        0.8  0.25 0.25
        0.7  0.7  0.3
    ];
    cells = {{"tetra10", [1 2 3 4 5 6 7 8 9 10]}};
    mesh = meshio.Mesh(pts, cells);
end
