function d = meshio_to_netgen_pmap()
% MESHIO_TO_NETGEN_PMAP  Inverse of netgen_to_meshio_pmap.
%   Mirrors meshio.netgen._netgen.meshio_to_netgen_pmap.
    persistent cache
    if isempty(cache)
        forward = meshio.netgen.common.netgen_to_meshio_pmap();
        ks = keys(forward);
        cache = configureDictionary("string", "cell");
        for i = 1:numel(ks)
            pmap = forward{ks(i)};
            n = numel(pmap);
            inv_pmap = zeros(1, n);
            inv_pmap(pmap) = 1:n;
            cache{ks(i)} = inv_pmap;
        end
    end
    d = cache;
end
