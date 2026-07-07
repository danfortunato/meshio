function mesh = quad8_mesh()
% QUAD8_MESH  Fixture mirroring helpers.quad8_mesh (1-based).
    d = 0.1;
    pts = [
        0    0    0
        1    0    0
        1    1    0
        0    1    0
        0.5  d    0
        1-d  0.5  0
        0.5  1-d  0
        d    0.5  0
        2    0    0
        2    1    0
        1.5 -d    0
        2+d  0.5  0
        1.5  1+d  0
    ];
    cells = {{"quad8", [1 2 3 4 5 6 7 8; 2 9 10 3 11 12 13 6]}};
    mesh = meshio.Mesh(pts, cells);
end
