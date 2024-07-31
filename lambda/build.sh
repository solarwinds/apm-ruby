#!/bin/sh
set -e

if [ $SOLARWINDS_SOURCE = 'Local' ]; then
    cd ../
    sudo apt-get update && sudo apt-get install -y --no-install-recommends ruby ruby-dev g++ make swig bison
    sudo gem install bundler
    sudo echo 'gem: --no-document' >> ~/.gemrc
    sudo bundle install --without development --without test
    sudo bundle exec rake fetch_oboe_file["prod"]
    sudo gem build solarwinds_apm.gemspec
    CURRENT_GEM=$(ls | grep solarwinds_apm-*.gem)
    mv $CURRENT_GEM lambda/otel/layer/
    cd -
fi

mkdir -p build

docker build --no-cache \
             --build-arg BUNDLE_RUBYGEMS__PKG__GITHUB__COM=${GITHUB_RUBY_TOKEN} \
             --progress plain \
             -f otel/Dockerfile_3_2 \
             -t sw-lambda-ruby-layer-3-2 otel

docker run --rm -v "$(pwd)/build:/out" sw-lambda-ruby-layer-3-2

docker build --no-cache \
             --build-arg BUNDLE_RUBYGEMS__PKG__GITHUB__COM=${GITHUB_RUBY_TOKEN} \
             --progress plain \
             -f otel/Dockerfile_3_3 \
             -t sw-lambda-ruby-layer-3-3 otel

docker run --rm -v "$(pwd)/build:/out" sw-lambda-ruby-layer-3-3

cd build/
mkdir solarwinds-apm && mkdir ruby && mkdir ruby/gems
unzip -q gems-3.2.0.zip -d ruby/gems/ && unzip -q gems-3.3.0.zip -d ruby/gems/
cp ../otel/layer/otel_wrapper.rb . && cp ../otel/layer/wrapper solarwinds-apm/
zip -qr ruby-layer-$MATRIX_ARCH.zip ruby/ solarwinds-apm/ otel_wrapper.rb
