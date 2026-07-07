function mesh = hex_mesh()
% HEX_MESH  Fixture mirroring helpers.hex_mesh (1-based).
    pts = [
        0 0 0; 1 0 0; 1 1 0; 0 1 0
        0 0 1; 1 0 1; 1 1 1; 0 1 1
    ];
    cells = {{"hexahedron", [1 2 3 4 5 6 7 8]}};
    mesh = meshio.Mesh(pts, cells);
end
