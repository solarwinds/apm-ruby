#!/usr/bin/env bash
# Copyright (c) SolarWinds, LLC.
# All rights reserved.
#
# This script can be used to run all or select tests in a Linux environment with
# the solarwinds_apm dependencies already installed, which is usually achieved by a combination of:
# - the setup of the docker image and
# - running the test_setup.sh script
#
# This script offers the following options:
# -g gemfile - restrict the tests to the ones associated with this gemfile (path from gem-root)
#

check_status() {
  status=$?
  [[ $status -gt $exit_status ]] && exit_status=$status
  [[ $status -ne 0 ]] && echo "!!! Test suite failed for $check_file_name with Ruby $ruby_version !!!"
}

gemfiles=(
  "gemfiles/unit.gemfile"
  "gemfiles/rails_6x.gemfile"
)

##
# Read opts
while getopts ":g:" opt; do
  case ${opt} in
    g ) # process option g
      gemfiles=("$OPTARG")
      ;;
    \? ) echo "
Usage: $0 [-g gemfile]
     -g gemfile - restrict the tests to the ones associated with this gemfile (path from gem-root)
"
      exit 1
      ;;
  esac
done

##
# setup files and env vars
exit_status=-1

rm -f gemfiles/*.lock

time=$(date "+%Y%m%d_%H%M")
export TEST_RUNS_FILE_NAME="log/testrun_$time.log"
export TEST_RUNS_TO_FILE=true
echo "logfile name: $TEST_RUNS_FILE_NAME"

ruby_version="$(ruby -e 'print(RUBY_VERSION)')"
echo "*** ruby version $ruby_version ***"

echo "Remove previous logfile"
rm log/*.log

##
# loop through gemfiles to set up and run tests
for gemfile in "${gemfiles[@]}" ; do

  echo "*** installing gems from $gemfile ***"
  if ! BUNDLE_GEMFILE=$gemfile bundle update; then
    echo "Problem during gem install. Skipping tests for $gemfile"
    exit_status=1
    continue
  fi
  # and here we are finally running the tests!!!
  BUNDLE_GEMFILE=$gemfile bundle exec rake test
  check_file_name=$gemfile
  check_status
done

# explicitly test for solarwinds initialization
if ! BUNDLE_GEMFILE=gemfiles/test_gems.gemfile bundle update; then
  echo "Problem during gem install. Skipping tests for $gemfile"
  exit_status=1
  continue
fi

# for dbo patch test
PATCH_TEST_FILE=$(find test/patch/*_test.rb -type f)
for file in $PATCH_TEST_FILE; do
  BUNDLE_GEMFILE=gemfiles/test_gems.gemfile bundle exec ruby -I test $file
  check_file_name=$file
  check_status
done

# create fake libsolarwinds_apm.so for testing
cd test/clib
ruby solarwinds_apm.rb
make
cd -
echo "Fake libsolarwinds_apm.so created"

NUMBER_FILE=$(find test/solarwinds_apm/init_test/*_test.rb -type f | wc -l)
for ((i = 1; i <= $NUMBER_FILE; i++)); do
  BUNDLE_GEMFILE=gemfiles/test_gems.gemfile bundle exec ruby -I test test/solarwinds_apm/init_test/init_${i}_test.rb
  check_file_name=init_${i}_test.rb
  check_status
done

echo ""
echo "--- SUMMARY ------------------------------"
grep -E '===|failures|FAIL|ERROR' "$TEST_RUNS_FILE_NAME"

exit $exit_status
