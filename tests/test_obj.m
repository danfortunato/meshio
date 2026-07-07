classdef test_obj < helpers.IOTestCase
    % TEST_OBJ  Mirrors meshio/tests/test_obj.py.

    properties (TestParameter)
        mesh_fixture = struct( ...
            empty    = @helpers.empty_mesh, ...
            tri      = @helpers.tri_mesh, ...
            quad     = @helpers.quad_mesh, ...
            tri_quad = @helpers.tri_quad_mesh, ...
            polygon  = @helpers.polygon_mesh)

        reference_case = struct( ...
            elephav = struct( ...
                filename      = "elephav.obj", ...
                ref_sum       = 3.678372172450000e+05, ...
                ref_num_cells = 1148))
    end

    methods (Test)
        function test_io(testCase, mesh_fixture)
            mesh = mesh_fixture();
            for k = 1:numel(mesh.cells)
                c = mesh.cells(k);
                mesh.cells(k) = meshio.CellBlock(c.type, int32(c.data));
            end
            helpers.write_read(testCase.TmpDir, ...
                @meshio.obj.write, @meshio.obj.read, mesh, 1.0e-12);
        end

        function test_reference_file(testCase, reference_case)
            % Mirrors @pytest.mark.skip("Fails point data consistency check.")
            % elephav.obj has 623 v's but only 622 vn's, which the Mesh
            % constructor rejects (same behaviour as Python).
            testCase.assumeFail("Fails point data consistency check.");

            here = fileparts(mfilename('fullpath'));
            filename = fullfile(here, "meshes", "obj", reference_case.filename);

            mesh = meshio.read(filename);
            tol = 1.0e-5;
            s = sum(mesh.points, "all");
            assert(abs(s - reference_case.ref_sum) < tol * abs(reference_case.ref_sum));
            assert(mesh.cells(1).type == "triangle");
            assert(size(mesh.cells(1).data, 1) == reference_case.ref_num_cells);
        end
    end
end
