#!/usr/bin/env sh
# Copyright (c) SolarWinds, LLC.
# All rights reserved.

echo "Start Run Setup"

pretty_name=$(grep PRETTY_NAME /etc/os-release | sed 's/PRETTY_NAME="//' | sed 's/"//')
if [ -r /etc/alpine-release ]; then
  apk update && apk add --upgrade git ruby-dev g++ make curl bash perl zlib-dev linux-headers shared-mime-info sqlite-dev grpc
elif [ -r /etc/debian_version ]; then
  # this is for ubuntu (> 22.04) and debian
  apt-get update && apt-get install -y git ruby-dev g++ make curl zlib1g-dev shared-mime-info
fi

echo "Finished Setup"

if [ ! -z "$RUBY_VERSION" ]; then {
  # If there is version provide, then run the test
  echo "Start Run Unit Test"
  export SW_APM_REPORTER=file
  mkdir log
  test/run_tests.sh -r "$RUBY_VERSION"
  echo "Finished Unit Test"
}
fi
