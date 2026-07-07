classdef test_off < helpers.IOTestCase
    % TEST_OFF  Mirrors meshio/tests/test_off.py.

    properties (TestParameter)
        mesh_fixture = struct(tri = @helpers.tri_mesh)
    end

    methods (Test)
        function test_io(testCase, mesh_fixture)
            helpers.write_read(testCase.TmpDir, ...
                @meshio.off.write, @meshio.off.read, ...
                mesh_fixture(), 1.0e-15);
        end

        function test_generic_io(testCase)
            helpers.generic_io(fullfile(testCase.TmpDir, 'test.off'));
            % With additional, insignificant suffix:
            helpers.generic_io(fullfile(testCase.TmpDir, 'test.0.off'));
        end
    end
end
