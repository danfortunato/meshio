function mesh = tri_mesh()
% TRI_MESH  Fixture mirroring helpers.tri_mesh in meshio/tests/helpers.py.
%   Indices are 1-based here (Python source uses 0-based).
    pts = [0 0 0; 1 0 0; 1 1 0; 0 1 0];
    cells = {{"triangle", [1 2 3; 1 3 4]}};
    mesh = meshio.Mesh(pts, cells);
end
