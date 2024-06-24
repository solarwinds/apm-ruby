#!/bin/sh
set -e

mkdir -p build

docker build --build-arg BUNDLE_RUBYGEMS__PKG__GITHUB__COM=${GITHUB_RUBY_TOKEN} \
             --progress plain \
             -f otel/Dockerfile_3_2 \
             -t sw-lambda-ruby-layer-3-2 otel

docker run --rm -v "$(pwd)/build:/out" sw-lambda-ruby-layer-3-2

docker build --build-arg BUNDLE_RUBYGEMS__PKG__GITHUB__COM=${GITHUB_RUBY_TOKEN} \
             --progress plain \
             -f otel/Dockerfile_3_3 \
             -t sw-lambda-ruby-layer-3-3 otel

docker run --rm -v "$(pwd)/build:/out" sw-lambda-ruby-layer-3-3

cd build/
mkdir solarwinds-apm && mkdir ruby && mkdir ruby/gems
unzip gems-3.2.0.zip -d ruby/gems/ && unzip gems-3.3.0.zip -d ruby/gems/
cp ../otel/layer/otel_wrapper.rb . && cp ../otel/layer/wrapper solarwinds-apm/
zip -r ruby-layer-$MATRIX_ARCH.zip ruby/ solarwinds-apm/ otel_wrapper.rb
