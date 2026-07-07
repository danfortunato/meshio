function tf = is_buffer(x, ~)
% IS_BUFFER  True if x is a file ID (from fopen), false if a path.
%   Mirrors meshio._files.is_buffer. The Python version checks for read/write
%   methods on a file-like object; the MATLAB analogue is a numeric FID.
%   The `mode` argument is accepted for signature parity but unused --
%   MATLAB file IDs carry their mode internally.
    tf = isnumeric(x) && isscalar(x);
end
