#!/bin/sh
set -e

mkdir -p build

docker build --build-arg MATRIX_ARCH=${MATRIX_ARCH} \
             --build-arg BUNDLE_RUBYGEMS__PKG__GITHUB__COM=${GITHUB_RUBY_TOKEN} \
             --progress plain -t sw-aws-otel-lambda-ruby-layer otel
docker run -e MATRIX_ARCH=${MATRIX_ARCH} --rm -v "$(pwd)/build:/out" sw-aws-otel-lambda-ruby-layer