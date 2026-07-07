function cd = cell_data_from_raw(cells, cell_data_raw)
% CELL_DATA_FROM_RAW  Split flat per-name data into per-block arrays.
%   Mirrors meshio._common.cell_data_from_raw.
    cd = configureDictionary("string", "cell");
    cs = zeros(1, numel(cells));
    for i = 1:numel(cells)
        cs(i) = cells(i).len();
    end
    cum = cumsum(cs);
    starts = [1, cum(1:end-1) + 1];
    ends   = cum;

    ks = keys(cell_data_raw);
    for i = 1:numel(ks)
        d = cell_data_raw{ks(i)};
        parts = cell(1, numel(cells));
        for k = 1:numel(cells)
            parts{k} = d(starts(k):ends(k), :);
        end
        cd{ks(i)} = parts;
    end
end
