#!/usr/bin/env bash

set -u
set -e

CMD='../ocamlmerlin -protocol'
JSON='["protocol", "version", 3]'
SEXP='("protocol" "version" 3)'

# Records whether or not a test has failed
TEST_FAILED=0

# COMPARE PROTOCOL INPUT OUTPUT
function compare {
  RUN="echo '$2' | $CMD $1"
  RES=$(eval "$RUN")
  if [ "$RES" != "$3" ]; then
    TEST_FAILED=1
    echo "Command:
  $RUN
failed with output:
  $RES
but expected:
  $3"
  fi
}

# Check JSON
compare 'json' "$JSON" '{"class":"return","value":{"selected":3,"latest":3,"merlin":"The Merlin toolkit version git-ca66a450fa59fbb9a47c3f0da7f2d342936bb1b0, for Ocaml 4.02.3"},"notifications":[]}'

# Check SEXP
compare 'sexp' "$SEXP" '((assoc) (class . "return") (value (assoc) (selected . 3) (latest . 3) (merlin . "The Merlin toolkit version git-ca66a450fa59fbb9a47c3f0da7f2d342936bb1b0, for Ocaml 4.02.3")) (notifications))'

exit "$TEST_FAILED"
