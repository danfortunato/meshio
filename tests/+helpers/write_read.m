function write_read(tmp_path, writer, reader, input_mesh, atol, extension)
% WRITE_READ  Write a mesh, read it back, compare. Mirrors helpers.write_read.
%   tmp_path  : directory path for temporary files
%   writer    : function handle to the format writer
%   reader    : function handle to the format reader
%   input_mesh: meshio.Mesh
%   atol      : absolute tolerance for numeric comparisons
%   extension : file extension including dot (default ".dat")
    arguments
        tmp_path
        writer
        reader
        input_mesh (1,1) meshio.Mesh
        atol       (1,1) double
        extension  (1,1) string = ".dat"
    end

    in_mesh = input_mesh.copy();   % deep copy to detect writer mutation

    p = fullfile(tmp_path, "test" + extension);
    % disp(input_mesh);
    writer(p, input_mesh);
    mesh = reader(p);

    % --- input mesh unchanged ---
    assert(strcmp(class(in_mesh.points), class(input_mesh.points)), ...
        "writer mutated point dtype");
    assert(all(abs(in_mesh.points - input_mesh.points) < atol, "all"), ...
        "writer mutated points");
    for i = 1:numel(in_mesh.cells)
        c0 = in_mesh.cells(i);
        c1 = input_mesh.cells(i);
        if startsWith(c0.type, "polyhedron")
            continue
        end
        assert(c0.type == c1.type, "writer mutated cell type");
        assert(isequal(size(c0.data), size(c1.data)), "writer mutated cell shape");
        assert(strcmp(class(c0.data), class(c1.data)), "writer mutated cell dtype");
        assert(isequal(c0.data, c1.data), "writer mutated cell data");
    end

    % --- output points match input (trim to input dim if writer padded) ---
    if size(in_mesh.points, 1) == 0
        assert(size(mesh.points, 1) == 0, "expected empty output");
    else
        n = size(in_mesh.points, 2);
        assert(all(abs(in_mesh.points - mesh.points(:, 1:n)) < atol, "all"), ...
            "points round-trip mismatch");
    end

    % --- cells match (sorted to handle block ordering) ---
    in_sorted  = sort_cells(in_mesh.cells);
    out_sorted = sort_cells(mesh.cells);
    assert(numel(in_sorted) == numel(out_sorted), ...
        "cell-block count mismatch: %d vs %d", numel(in_sorted), numel(out_sorted));
    for i = 1:numel(in_sorted)
        c0 = in_sorted(i);
        c1 = out_sorted(i);
        assert(c0.type == c1.type, "cell type mismatch: %s vs %s", c0.type, c1.type);
        if startsWith(c0.type, "polyhedron")
            for k = 1:numel(c0.data)
                for f = 1:numel(c0.data{k})
                    assert(all(abs(c0.data{k}{f} - c1.data{k}{f}) < atol), ...
                        "polyhedron face mismatch");
                end
            end
        else
            % disp("a"); disp(c0.data);
            % disp("b"); disp(c1.data);
            assert(isequal(c0.data, c1.data), "cell data mismatch");
        end
    end

    % --- point_data ---
    pkeys = keys(in_mesh.point_data);
    for i = 1:numel(pkeys)
        v0 = in_mesh.point_data{pkeys(i)};
        v1 = mesh.point_data{pkeys(i)};
        assert(all(abs(v0 - v1) < atol, "all"), ...
            "point_data('%s') round-trip mismatch", pkeys(i));
    end

    % --- cell_data ---
    % disp(in_mesh.cell_data);
    % disp(mesh.cell_data);
    ckeys = keys(in_mesh.cell_data);
    for i = 1:numel(ckeys)
        d0 = in_mesh.cell_data{ckeys(i)};
        d1 = mesh.cell_data{ckeys(i)};
        for k = 1:numel(d0)
            assert(all(abs(d0{k} - d1{k}) < atol, "all"), ...
                "cell_data('%s') block %d round-trip mismatch", ckeys(i), k);
        end
    end

    % --- field_data ---
    fkeys = keys(in_mesh.field_data);
    for i = 1:numel(fkeys)
        v0 = in_mesh.field_data{fkeys(i)};
        v1 = mesh.field_data{fkeys(i)};
        assert(isequal(v0, v1) || all(abs(v0 - v1) < atol, "all"), ...
            "field_data('%s') round-trip mismatch", fkeys(i));
    end

    % --- cell_sets (best-effort; skipped if missing in output) ---
    skeys = keys(in_mesh.cell_sets);
    for i = 1:numel(skeys)
        if ~isKey(mesh.cell_sets, skeys(i))
            continue
        end
        d0 = in_mesh.cell_sets{skeys(i)};
        d1 = mesh.cell_sets{skeys(i)};
        for k = 1:numel(d0)
            assert(all(abs(d0{k} - d1{k}) < atol, "all"), ...
                "cell_sets('%s') block %d round-trip mismatch", skeys(i), k);
        end
    end
end


function sorted = sort_cells(blocks)
    if isempty(blocks)
        sorted = blocks;
        return
    end
    keys_ = strings(1, numel(blocks));
    for i = 1:numel(blocks)
        if startsWith(blocks(i).type, "polyhedron")
            keys_(i) = blocks(i).type;
        else
            keys_(i) = sprintf("%s|%010d", blocks(i).type, blocks(i).data(1,1));
        end
    end
    [~, order] = sort(keys_);
    sorted = blocks(order);
end
