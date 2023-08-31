#!/usr/bin/env sh
# Copyright (c) SolarWinds, LLC.
# All rights reserved.

echo "Start Run Setup"
if [ -r /etc/alpine-release ]; then
  if [ "$(uname -m)" = "aarch64" ]; then
    # alpine ruby seems have problem with google-protobuf
    echo "Tests do not work on aarch64 alpine, skipping."
    exit
  else
    apk update && apk add --upgrade git ruby-dev g++ make curl bash perl zlib-dev linux-headers shared-mime-info sqlite-dev grpc
  fi
elif [ -r /etc/debian_version ]; then
  # this is for ubuntu (> 22.04) and debian
  apt-get update && apt-get install -y git ruby-dev g++ make curl zlib1g-dev shared-mime-info libsqlite3-dev xz-utils
fi
echo "Finished Setup"

if [ -n "$RUN_TESTS" ]; then {
  echo "Start Run Unit Test"
  export SW_APM_REPORTER=file
  mkdir -p log
  test/run_tests.sh
  status=$?
  echo "Finished Unit Test"
  exit $status
}
fi
