function write_data(fid, tag, name, data, binary)
% WRITE_DATA  Write a $NodeData or $ElementData block.
%   Mirrors meshio.gmsh.common._write_data.
    arguments
        fid
        tag    (1,1) string
        name   (1,1) string
        data
        binary (1,1) logical
    end
    fprintf(fid, "$%s\n", tag);
    % <http://gmsh.info/doc/texinfo/gmsh.html>:
    % > Number of string tags.
    % > gives the number of string tags that follow. By default the first
    % > string-tag is interpreted as the name of the post-processing view and
    % > the second as the name of the interpolation scheme. The interpolation
    % > scheme is provided in the $InterpolationScheme section (see below).
    fprintf(fid, '1\n"%s"\n', name);
    fprintf(fid, "1\n0.0\n");
    % three integer tags:
    % time step
    % number of components
    if isvector(data)
        num_components = 1;
    else
        num_components = size(data, 2);
    end
    if ~ismember(num_components, [1, 3, 9])
        error("meshio:WriteError", ...
            "Gmsh only permits 1, 3, or 9 components per data field.");
    end

    % Cut off the last dimension in case it's 1. This avoids problems with
    % writing the data.
    n = size(data, 1);
    fprintf(fid, "3\n0\n%d\n%d\n", num_components, n);
    % num data items
    % actually write the data
    if binary
        for k = 1:n
            fwrite(fid, int32(k), 'int32');
            if num_components == 1
                fwrite(fid, double(data(k)), 'double');
            else
                fwrite(fid, double(data(k, :)), 'double');
            end
        end
        fprintf(fid, "\n");
    else
        % TODO unify
        if num_components == 1
            out = [(1:n)', double(data(:))];
            fprintf(fid, "%d %.17g\n", out');
        else
            out = [(1:n)', double(data)];
            fmt = ['%d', repmat(' %.17g', 1, num_components), '\n'];
            fprintf(fid, fmt, out');
        end
    end

    fprintf(fid, "$End%s\n", tag);
end
