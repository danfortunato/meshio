function mesh = hex20_mesh()
% HEX20_MESH  Fixture mirroring helpers.hex20_mesh (1-based).
    pts = [
        0   0   0
        1   0   0
        1   1   0
        0   1   0
        0   0   1
        1   0   1
        1   1   1
        0   1   1
        %
        0.5 0   0
        1   0.5 0
        0.5 1   0
        0   0.5 0
        %
        0   0   0.5
        1   0   0.5
        1   1   0.5
        0   1   0.5
        %
        0.5 0   1
        1   0.5 1
        0.5 1   1
        0   0.5 1
    ];
    cells = {{"hexahedron20", 1:20}};
    mesh = meshio.Mesh(pts, cells);
end
