-- Shared SQL correctness regression suite.
-- Invoke through psql -X -v ON_ERROR_STOP=1.
\set ON_ERROR_STOP on
\ir ../migrations/V0001__demo_correctness_patterns.sql
\ir 07_test_fixtures.sql
\ir 08_regression_tests.sql