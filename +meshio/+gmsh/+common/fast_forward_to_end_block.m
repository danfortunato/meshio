function fast_forward_to_end_block(fid, block)
% FAST_FORWARD_TO_END_BLOCK  Read until "$End<block>" or EOF.
%   Mirrors meshio.gmsh.common._fast_forward_to_end_block.
    target = "$End" + string(block);
    while true
        raw = fgetl(fid);
        if ~ischar(raw)
            warning("meshio:gmsh:unclosedBlock", ...
                "$%s not closed by $End%s.", block, block);
            return
        end
        if strtrim(string(raw)) == target
            return
        end
    end
end
