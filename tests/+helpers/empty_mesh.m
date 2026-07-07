function mesh = empty_mesh()
% EMPTY_MESH  Fixture: zero points, zero cells. Mirrors helpers.empty_mesh.
    mesh = meshio.Mesh(zeros(0, 3), {});
end
