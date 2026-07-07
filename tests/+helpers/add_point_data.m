function mesh2 = add_point_data(mesh, dim, options)
% ADD_POINT_DATA  Mirrors helpers.add_point_data.
%   Adds random point_data arrays with keys 'a', 'b', ... up to num_tags entries.
%   mesh : input meshio.Mesh
%   dim  : 1 for scalar per point, >1 for vector per point
    arguments
        mesh
        dim
        options.num_tags (1,1) double = 2
        options.seed     (1,1) double = 0
        options.dtype    (1,1) string = "double"
    end

    mesh2 = mesh.copy();
    n = size(mesh.points, 1);
    if dim == 1
        sz = [n, 1];
    else
        sz = [n, dim];
    end

    rng_state = rng(options.seed);
    cleanup = onCleanup(@() rng(rng_state)); %#ok<NASGU>

    letters = char('a' + (0:options.num_tags - 1));
    pd = configureDictionary("string", "cell");
    for k = 1:options.num_tags
        x = 100 * rand(sz);
        switch options.dtype
            case {"double", "float64"}
                v = double(x);
            case {"single", "float", "float32"}
                v = single(x);
            case {"int", "int32"}
                v = int32(x);
            case "int64"
                v = int64(x);
            case "uint8"
                v = uint8(x);
            otherwise
                v = cast(x, options.dtype);
        end
        pd{string(letters(k))} = v;
    end
    mesh2.point_data = pd;
end
