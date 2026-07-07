function raw = raw_from_cell_data(cell_data)
% RAW_FROM_CELL_DATA  Concatenate per-block arrays into flat per-name arrays.
%   Mirrors meshio._common.raw_from_cell_data.
    raw = configureDictionary("string", "cell");
    ks = keys(cell_data);
    for i = 1:numel(ks)
        raw{ks(i)} = vertcat(cell_data{ks(i)}{:});
    end
end
