classdef test_tetgen < helpers.IOTestCase
    % TEST_TETGEN  Mirrors meshio/tests/test_tetgen.py.

    properties (TestParameter)
        mesh_fixture = struct(tet = @helpers.tet_mesh)

        reference_case = struct( ...
            mesh = struct( ...
                filename       = "mesh.ele", ...
                point_ref_sum  = 12, ...
                cell_ref_sum   = 373))
    end

    methods (Test)
        function test(testCase, mesh_fixture)
            helpers.write_read(testCase.TmpDir, ...
                @meshio.tetgen.write, @meshio.tetgen.read, ...
                mesh_fixture(), 1.0e-15, ".node");
        end

        function test_point_cell_refs(testCase, reference_case)
            here = fileparts(mfilename('fullpath'));
            filename = fullfile(here, "meshes", "tetgen", reference_case.filename);
            mesh = meshio.read(filename);
            testCase.assertEqual( ...
                sum(mesh.point_data{"tetgen:ref"}), reference_case.point_ref_sum);
            testCase.assertEqual( ...
                sum(mesh.cell_data{"tetgen:ref"}{1}), reference_case.cell_ref_sum);
        end
    end
end
