function mesh2 = add_cell_data(mesh, specs)
% ADD_CELL_DATA  Mirrors helpers.add_cell_data.
%   specs : cell array of {name, shape, dtype} triples
%   For each spec, creates one array per cell block with shape
%   [n_cells_in_block, shape...] cast to dtype.
    mesh2 = mesh.copy();

    rng_state = rng(0);
    cleanup = onCleanup(@() rng(rng_state)); %#ok<NASGU>

    cd = configureDictionary("string", "cell");
    for s = 1:numel(specs)
        name  = specs{s}{1};
        shape = specs{s}{2};
        dtype = specs{s}{3};
        block_data = cell(1, numel(mesh.cells));
        for k = 1:numel(mesh.cells)
            n = mesh.cells(k).len();
            if isempty(shape)
                sz = [n, 1];
            else
                sz = [n, shape];
            end
            v = 100 * rand(sz);
            block_data{k} = cast(v, dtype);
        end
        cd{string(name)} = block_data;
    end

    % Keep cell-data from the original mesh.
    ck = keys(mesh.cell_data);
    for i = 1:numel(ck)
        cd{ck(i)} = mesh.cell_data{ck(i)};
    end
    mesh2.cell_data = cd;
end
