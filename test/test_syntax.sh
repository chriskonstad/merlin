#!/usr/bin/env bash

set -u
set -e

CMD='../ocamlmerlin -syntax-check'

# Records whether or not a test has failed
TEST_FAILED=0

# COMPARE FILE EXPECTED
function compare {
  RUN="$CMD $1"
  RES=$($RUN)
  if [ "$RES" != "$2" ]; then
    TEST_FAILED=1
    echo "Command:
  $RUN
failed with output:
  $RES
but expected:
  $2"
  fi
}

# Check a file that isn't right
compare 'tests_syntax_check/test.ml' 'tests_syntax_check/test.ml:4:19:Error: This expression has type string but an expression was expected of type. int'

# Check a file that has no errors
compare 'tests_syntax_check/test_right.ml' ''

exit "$TEST_FAILED"
