classdef test_stl < helpers.IOTestCase
    % TEST_STL  Mirrors meshio/tests/test_stl.py.

    properties (TestParameter)
        mesh_fixture = struct( ...
            empty = @helpers.empty_mesh, ...
            tri   = @helpers.tri_mesh)
        % binary STL only operates in single precision, hence the looser tol
        format_spec = struct( ...
            ascii  = struct(binary = false, tol = 1.0e-15), ...
            binary = struct(binary = true,  tol = 1.0e-8))
    end

    methods (TestMethodSetup)
        function suppress_expected_warnings(testCase)
            % Writing a mesh with no triangle cells (the empty fixture) warns,
            % as does Python meshio; expected here, so keep it out of the log.
            testCase.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture( ...
                "meshio:stl:noTriangles"));
        end
    end

    methods (Test)
        function test_io(testCase, mesh_fixture, format_spec)
            writer = @(p, m) meshio.stl.write(p, m, binary=format_spec.binary);
            helpers.write_read(testCase.TmpDir, ...
                writer, @meshio.stl.read, ...
                mesh_fixture(), format_spec.tol);
        end
    end
end
