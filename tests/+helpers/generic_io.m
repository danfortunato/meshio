function generic_io(filepath)
% GENERIC_IO  Mirrors helpers.generic_io: round-trip via meshio.write_points_cells.
    m = helpers.tri_mesh();
    meshio.write_points_cells(filepath, m.points, m.cells);
    out_mesh = meshio.read(filepath);
    assert(all(abs(out_mesh.points - m.points) < 1e-15, "all"), ...
        "generic_io points mismatch");
end
