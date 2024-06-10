#!/bin/sh
set -e

mkdir -p build

docker build --progress plain -t aws-otel-lambda-ruby-layer otel
docker run -e MATRIX_ARCH=${MATRIX_ARCH} \
           -e BUNDLE_RUBYGEMS__PKG__GITHUB__COM=${GITHUB_RUBY_TOKEN} \
           -e LAMBDA_TASK_ROOT=/fake_lambda_task_root/ \
           --rm -v "$(pwd)/build:/out" aws-otel-lambda-ruby-layer

