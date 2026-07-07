fprintf('=== Testing meshio ===\n');

here     = fileparts(mfilename('fullpath'));
testsDir = fullfile(here, 'tests');

results = runtests(testsDir, 'IncludeSubfolders', false, 'OutputDetail', 0);

if isempty(results)
    error('meshio:noTests', 'No tests were discovered under %s.', testsDir);
end

nfailed = nnz([results.Failed]);
if nfailed > 0
    error('meshio:testFailure', '%d of %d meshio tests failed.', ...
        nfailed, numel(results));
end

fprintf('=== meshio test passed (%d run, %d skipped) ===\n', ...
    numel(results), nnz([results.Incomplete]));
