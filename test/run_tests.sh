#!/usr/bin/env bash
# Copyright (c) SolarWinds, LLC.
# All rights reserved.
#
# This script can be used to run all or select tests in a Linux environment with
# the solarwinds_apm dependencies already installed
# This is usually achieved by a combination of:
# - the setup of the docker image and
# - running the ruby_setup.sh script
#
# This script offers the following options:
# -r ruby-version   - restrict the tests to run with this ruby version
# -g gemfile        - restrict the tests to the ones associated with this gemfile (path from gem-root)
# 

##
# Set up the default rubies, gemfiles and database types
#
# !!! When changing or adding ruby versions, the versions have to be
# updated in the docker images as well, locally and in github !!!
##

rubies=("3.1.0" "3.0.6" "2.7.5" "2.6.9")

gemfiles=(
  "gemfiles/unit.gemfile"
  "gemfiles/rails_6x.gemfile"
)

##
# Read opts
copy=0
while getopts ":r:g:" opt; do
  case ${opt} in
    r ) # process option a
      rubies=("$OPTARG")
      ;;
    g ) # process option t
      gemfiles=("$OPTARG")
      ;;
    \? ) echo "
Usage: $0 [-r ruby-version] [-g gemfile] [-d database type] [-p prepared_statements] [-c copy files]

     -r ruby-version        - restrict the tests to run with this ruby version
     -g gemfile             - restrict the tests to the ones associated with this gemfile (path from gem-root)
"
      exit 1
      ;;
  esac
done

##
# setup files and env vars
arch=$(uname -m)
dir=$(pwd)
exit_status=-1

rm -f gemfiles/*.lock

time=$(date "+%Y%m%d_%H%M")
export TEST_RUNS_FILE_NAME="log/testrun_$time.log"
export TEST_RUNS_TO_FILE=true
echo "logfile name: $TEST_RUNS_FILE_NAME"

##
# loop through rubies, gemfiles, and database types to set up and run tests
for ruby in "${rubies[@]}" ; do

  for gemfile in "${gemfiles[@]}" ; do
    export BUNDLE_GEMFILE=$gemfile

    # alpine ruby seems have problem with google-protobuf
    if [[ -r /etc/alpine-release && "$arch" == "aarch64" ]]; then continue; fi

    echo "*** installing gems from $BUNDLE_GEMFILE ***"
    if ! bundle update; then
      echo "Problem during gem install. Skipping tests for $gemfile"
      exit_status=1
      continue
    fi
    # and here we are finally running the tests!!!
    bundle exec rake test
    status=$?
    [[ $status -gt $exit_status ]] && exit_status=$status
    [[ $status -ne 0 ]] && echo "!!! Test suite failed for $gemfile with Ruby $ruby !!!"
  done
done

echo ""
echo "--- SUMMARY ------------------------------"
grep -E '===|failures|FAIL|ERROR' "$TEST_RUNS_FILE_NAME"

if [ "$copy" -eq 1 ]; then
    mv "$TEST_RUNS_FILE_NAME" "$dir"/log/
fi

exit $exit_status