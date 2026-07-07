function d = netgen_to_meshio_pmap()
% NETGEN_TO_MESHIO_PMAP  Permutation maps from netgen node order to meshio.
%   Mirrors meshio.netgen._netgen.netgen_to_meshio_pmap.
%   Indices below are 1-based (Python source uses 0-based).
    persistent cache
    if isempty(cache)
        cache = configureDictionary("string", "cell");
        cache{"vertex"}       = [1];
        cache{"line"}         = [1 2];
        cache{"triangle"}     = [1 2 3];
        cache{"triangle6"}    = [1 2 3 6 4 5];
        cache{"quad"}         = [1 2 3 4];
        cache{"quad8"}        = [1 2 3 4 5 8 6 7];
        cache{"tetra"}        = [1 3 2 4];
        cache{"tetra10"}      = [1 3 2 4 6 8 5 7 10 9];
        cache{"pyramid"}      = [1 4 3 2 5];
        cache{"pyramid13"}    = [1 4 3 2 5 8 7 9 6 10 13 12 11];
        cache{"wedge"}        = [1 3 2 4 6 5];
        cache{"wedge15"}      = [1 3 2 4 6 5 8 9 7 14 15 13 10 12 11];
        cache{"hexahedron"}   = [1 4 3 2 5 8 7 6];
        cache{"hexahedron20"} = [1 4 3 2 5 8 7 6 11 10 12 9 17 20 19 18 15 14 16 13];
    end
    d = cache;
end
