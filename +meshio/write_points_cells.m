function write_points_cells(filename, points, cells, varargin, options)
% WRITE_POINTS_CELLS  Convenience wrapper to build a Mesh and write it.
%   Mirrors meshio._helpers.write_points_cells.
%
%   meshio.write_points_cells(filename, points, cells)
%   meshio.write_points_cells(filename, points, cells, extra1, extra2, ..., Name=Value, ...)
%
%   Extra positional args are forwarded to the underlying writer (parallels
%   Python's **kwargs forwarding).
%   Supported name-value options:
%     point_data, cell_data, field_data, point_sets, cell_sets  (dictionaries)
%     file_format  (string; deduced from extension if omitted)
    arguments
        filename
        points
        cells
    end
    arguments (Repeating)
        varargin
    end
    arguments
        options.point_data  = []
        options.cell_data   = []
        options.field_data  = []
        options.point_sets  = []
        options.cell_sets   = []
        options.file_format = []
    end

    mesh = meshio.Mesh(points, cells,    ...
        point_data = options.point_data, ...
        cell_data  = options.cell_data,  ...
        field_data = options.field_data, ...
        point_sets = options.point_sets, ...
        cell_sets  = options.cell_sets);

    meshio.write(filename, mesh, options.file_format, varargin{:});
end
