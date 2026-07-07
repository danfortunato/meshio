function mesh2 = add_field_data(mesh, value, dtype)
% ADD_FIELD_DATA  Mirrors helpers.add_field_data.
    mesh2 = mesh.copy();
    fd = configureDictionary("string", "cell");
    fd{"a"} = cast(value, dtype);
    mesh2.field_data = fd;
end
