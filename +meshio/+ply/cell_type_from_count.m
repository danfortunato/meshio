function t = cell_type_from_count(n)
% CELL_TYPE_FROM_COUNT  Mirror of meshio.ply._ply.cell_type_from_count.
    if n == 1
        t = "vertex";
    elseif n == 2
        t = "line";
    elseif n == 3
        t = "triangle";
    elseif n == 4
        t = "quad";
    else
        t = "polygon";
    end
end
