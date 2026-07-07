function mesh = read(filename)
% READ  Read a Gmsh msh file.
%   Mirrors meshio.gmsh.main.read.
%   Reads the $MeshFormat header to detect version + ASCII/binary,
%   then dispatches to the version-specific reader.
%   The various versions of the format are specified at
%   <http://gmsh.info/doc/texinfo/gmsh.html#File-formats>.
    fid = fopen(filename, 'r');
    if fid < 0
        error("meshio:ReadError", "Cannot open '%s'.", filename);
    end

    line = strtrim(string(fgetl(fid)));

    % skip any $Comments/$EndComments sections
    while line == "$Comments"
        meshio.gmsh.common.fast_forward_to_end_block(fid, "Comments");
        line = strtrim(string(fgetl(fid)));
    end

    if line ~= "$MeshFormat"
        fclose(fid);
        error("meshio:ReadError", "Expected `$MeshFormat`, got '%s'.", line);
    end

    [fmt_version, data_size, is_ascii, endian_byte] = read_header(fid);

    % If binary, we need the file open with the correct endianness.
    if ~is_ascii && endian_byte ~= 'n'
        pos = ftell(fid);
        fclose(fid);
        fid = fopen(filename, 'r', endian_byte);
        fseek(fid, pos, 'bof');
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    % Some mesh files out there have the version specified as version "2" when it really is
    % "2.2". Same with "4" vs "4.1".
    switch fmt_version
        case {"2", "2.2"}
            mesh = meshio.gmsh.v22.read_buffer(fid, is_ascii, data_size);
        case "4.0"
            mesh = meshio.gmsh.v40.read_buffer(fid, is_ascii, data_size);
        case {"4", "4.1"}
            mesh = meshio.gmsh.v41.read_buffer(fid, is_ascii, data_size);
        otherwise
            error("meshio:ReadError", ...
                "Need mesh format in {2, 2.2, 4, 4.0, 4.1} (got %s)", fmt_version);
    end
end


function [fmt_version, data_size, is_ascii, endian_byte] = read_header(fid)
% Read the mesh format block, specified as
%
%   version(ASCII double; currently 4.1)
%     file-type(ASCII int; 0 for ASCII mode, 1 for binary mode)
%     data-size(ASCII int; sizeof(size_t))
%   < int with value one; only in binary mode, to detect endianness >
%
% though here the version is left as str.

    % http://gmsh.info/doc/texinfo/gmsh.html#MSH-file-format
    raw = fgetl(fid);
    % Split the line
    %   4.1 0 8
    % into its components.
    parts = regexp(strtrim(raw), '\s+', 'split');
    fmt_version = string(parts{1});
    file_type = parts{2};
    if ~ismember(file_type, {'0', '1'})
        error("meshio:ReadError", "Bad file-type field in $MeshFormat: %s", file_type);
    end
    is_ascii = strcmp(file_type, '0');
    data_size = str2double(parts{3});
    endian_byte = 'n';

    if ~is_ascii
        % The next line is the integer 1 in bytes. Useful for checking endianness.
        % Just assert that we get 1 here.
        one = fread(fid, 1, 'int32=>int32');
        if one ~= 1
            [~, ~, native] = computer;
            if native == 'L'
                endian_byte = 'b';
            else
                endian_byte = 'l';
            end
            if swapbytes(one) ~= 1
                error("meshio:ReadError", "Endianness check byte not 1.");
            end
        end
        fgetl(fid); %#ok<*FGETL>
    end
    meshio.gmsh.common.fast_forward_to_end_block(fid, "MeshFormat");
end
