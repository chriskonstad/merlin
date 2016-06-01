#!/usr/bin/env bash

MERLIN="../ocamlmerlin"
TEST_DIR="tests_interactive"

if [ "$1" = "--update" ]; then
  UPDATE=1
  shift 1
else
  UPDATE=0
fi 

if test -n "$1" ; then
    # Use more appropriate jsondiff if available
    if [ -n "$DIFF" ]; then
      :
    elif which jsondiff >& /dev/null; then
      DIFF="jsondiff -color"
    else
      DIFF="diff -u"
    fi

    out=`mktemp`
    while test -n "$1"; do
      (cd "$TEST_DIR" && bash $1.in) | "$MERLIN" > $out
      if [ -r ./"$TEST_DIR"/$1.out ]; then
        $DIFF ./"$TEST_DIR"/$1.out $out
      else
        less $out
      fi
      if [ "$UPDATE" = 1 ]; then
        cp $out ./"$TEST_DIR"/$1.out
      fi
      shift 1
    done
    rm $out
else
    for file in "$TEST_DIR"/*.in; do
        test_nb=`basename $file .in`
        temp_out=`mktemp`
        real_out=`echo "$file"|sed 's/\.in$/.out/'`
        (cd "$TEST_DIR" && bash $test_nb.in) | "$MERLIN" > $temp_out
        if [ "$UPDATE" = 1 ]; then
            echo "############## $test_nb ##############"
            diff $temp_out $real_out
            mv $temp_out $real_out
        else
            diff $temp_out $real_out > /dev/null
            if [[ $? != 0 ]] ; then
                echo -e "$test_nb: \e[1;31mFAILED\e[0m"
                echo "    run ./test.sh $test_nb to have more informations"
            else
                echo -e "$test_nb: \e[1;32mOK\e[0m"
            fi
            rm $temp_out
        fi
    done
fi
