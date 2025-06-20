#!/bin/sh
set -e

if [ $SOLARWINDS_SOURCE = 'Local' ]; then
    cd ../
    sudo apt-get update && sudo apt-get install -y --no-install-recommends ruby ruby-dev g++ make
    sudo gem install bundler
    sudo echo 'gem: --no-document' >> ~/.gemrc
    sudo bundle config set --local without 'test development'
    sudo gem build solarwinds_apm.gemspec
    CURRENT_GEM=$(ls | grep solarwinds_apm-*.gem)
    mv $CURRENT_GEM lambda/otel/layer/
    cd -
fi

mkdir -p build

for ruby_version in 3.2 3.3 3.4; do
  docker build --no-cache \
               --build-arg RUBY_VERSION=${ruby_version} \
               --progress plain \
               -f otel/Dockerfile \
               -t sw-lambda-ruby-layer-${ruby_version} otel

  docker run --rm -v "$(pwd)/build:/out" sw-lambda-ruby-layer-${ruby_version}
done

cd build/
mkdir solarwinds-apm && mkdir ruby && mkdir ruby/gems
unzip -q gems-3.2.0.zip -d ruby/gems/ && unzip -q gems-3.3.0.zip -d ruby/gems/ && unzip -q gems-3.4.0.zip -d ruby/gems/
cp ../otel/layer/otel_wrapper.rb . && cp ../otel/layer/wrapper solarwinds-apm/
zip -qr ruby-layer.zip ruby/ solarwinds-apm/ otel_wrapper.rb
