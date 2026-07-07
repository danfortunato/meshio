classdef test_netgen < helpers.IOTestCase
    % TEST_NETGEN  Mirrors meshio/tests/test_netgen.py.

    properties (TestParameter)
        mesh_fixture = struct( ...
            empty        = @helpers.empty_mesh, ...
            line         = @helpers.line_mesh, ...
            tri_2d       = @helpers.tri_mesh_2d, ...
            tri          = @helpers.tri_mesh, ...
            triangle6    = @helpers.triangle6_mesh, ...
            quad         = @helpers.quad_mesh, ...
            quad8        = @helpers.quad8_mesh, ...
            tri_quad     = @helpers.tri_quad_mesh, ...
            tet          = @helpers.tet_mesh, ...
            tet10        = @helpers.tet10_mesh, ...
            hex          = @helpers.hex_mesh, ...
            hex20        = @helpers.hex20_mesh, ...
            pyramid      = @helpers.pyramid_mesh, ...
            wedge        = @helpers.wedge_mesh, ...
            tri_index    = @() helpers.add_cell_data(helpers.tri_mesh, {{"netgen:index", [], "int32"}}))

        suffix = struct(vol = ".vol", vol_gz = ".vol.gz")

        periodic_case = struct( ...
            periodic_1d = "periodic_1d.vol", ...
            periodic_2d = "periodic_2d.vol", ...
            periodic_3d = "periodic_3d.vol")
    end

    methods (Test)
        function test(testCase, mesh_fixture, suffix)
            helpers.write_read(testCase.TmpDir, ...
                @meshio.netgen.write, @meshio.netgen.read, ...
                mesh_fixture(), 1.0e-13, suffix);
        end

        function test_advanced(testCase, periodic_case)
            here = fileparts(mfilename('fullpath'));
            in_path  = fullfile(here, "meshes", "netgen", periodic_case);
            mesh     = meshio.read(in_path);
            out_path = fullfile(testCase.TmpDir, periodic_case + "_out.vol");
            mesh.write(out_path);
            mesh_out = meshio.read(out_path);

            expected = expected_periodic_data(periodic_case);

            testCase.assertTrue(isequal( ...
                mesh.info{"netgen:identifications"}, expected.identifications));
            testCase.assertTrue(isequal( ...
                mesh.info{"netgen:identifications"}, ...
                mesh_out.info{"netgen:identifications"}));
            testCase.assertTrue(isequal( ...
                mesh.info{"netgen:identificationtypes"}, expected.identificationtypes));
            testCase.assertTrue(isequal( ...
                mesh.info{"netgen:identificationtypes"}, ...
                mesh_out.info{"netgen:identificationtypes"}));

            fk = keys(mesh.field_data);
            for i = 1:numel(fk)
                vv = mesh.field_data{fk(i)};
                testCase.assertTrue(isequal(vv, expected.field_data{fk(i)}));
                testCase.assertTrue(isequal(vv, mesh_out.field_data{fk(i)}));
            end

            in_cd  = mesh.cell_data{"netgen:index"};
            out_cd = mesh_out.cell_data{"netgen:index"};
            for k = 1:numel(in_cd)
                testCase.assertTrue(isequal(in_cd{k}, out_cd{k}));
            end
        end
    end
end


function out = expected_periodic_data(name)
    switch name
        case "periodic_1d.vol"
            out.identifications     = [1, 51, 1];
            out.identificationtypes = 2;
            out.field_data          = configureDictionary("string", "cell");
        case "periodic_2d.vol"
            out.identifications = [2 1 4; 3 4 4; 9 17 4; 10 18 4; 11 19 4; 12 20 4];
            out.identificationtypes = [1 1 1 2];
            fd = configureDictionary("string", "cell");
            fd{"outer"}    = [3, 1];
            fd{"periodic"} = [4, 1];
            out.field_data = fd;
        case "periodic_3d.vol"
            out.identifications = [ ...
                 1  3 1;  2  5 1;  4  7 1;  6  8 1; ...
                 9 11 1; 10 12 1; 15 13 1; 16 14 1; ...
                21 19 1; 22 20 1; 25 23 1; 26 24 1; ...
                38 54 1; 39 55 1; 40 56 1];
            out.identificationtypes = 2;
            fd = configureDictionary("string", "cell");
            fd{"outer"}   = [6, 2];
            fd{"default"} = [3, 2];
            out.field_data = fd;
        otherwise
            error("Unknown periodic case: %s", name);
    end
end
