classdef IOTestCase < matlab.unittest.TestCase
    % IOTESTCASE  Shared base for meshio I/O tests.
    %   Puts the +meshio package on the path (once per class) and gives each
    %   test a fresh temporary folder.

    properties
        TmpDir char
    end

    methods (TestClassSetup)
        function add_meshio_path(testCase)
            % This file lives at matlab/tests/+helpers/IOTestCase.m;
            % matlab/ is three fileparts up.
            here = fileparts(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture( ...
                matlab.unittest.fixtures.PathFixture(here));
        end
    end

    methods (TestMethodSetup)
        function setup_tmp(testCase)
            f = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.TmpDir = f.Folder;
        end
    end
end
