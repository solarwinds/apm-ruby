#!/bin/sh
set -xe

echo "Build from source: $SOLARWINDS_SOURCE. Publish to $PUBLISH_DEST."
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

for ruby_version in $ALLOWED_RUBY_VERSION; do
  if [ "$BIGDECIMAL" = 'true' ]; then
    docker buildx build --no-cache \
                 --platform linux/arm64
                 --build-arg RUBY_VERSION=${ruby_version} \
                 --progress plain \
                 -f otel/Dockerfile \
                 -t sw-lambda-ruby-layer-${ruby_version} otel

    docker run --rm -v "$(pwd)/build:/out" sw-lambda-ruby-layer-${ruby_version}
  else
    docker build --no-cache \
                 --build-arg RUBY_VERSION=${ruby_version} \
                 --progress plain \
                 -f otel/Dockerfile \
                 -t sw-lambda-ruby-layer-${ruby_version} otel

    docker run --rm -v "$(pwd)/build:/out" sw-lambda-ruby-layer-${ruby_version}
  fi
done

cd build/
mkdir -p ruby/gems

for ruby_version in $ALLOWED_RUBY_VERSION; do
  unzip -q gems-$ruby_version.0.zip -d ruby/gems/
done

if [ "$BIGDECIMAL" = 'true' ]; then
  zip -qr bigdecimal-aarch64.zip ruby/gems/3.4.0/extensions/aarch64-linux/3.4.0/bigdecimal-*/
  rm -rf ruby/
else
  mkdir solarwinds-apm
  cp ../otel/layer/otel_wrapper.rb . && cp ../otel/layer/wrapper solarwinds-apm/
  zip -qr ruby-layer.zip ruby/ solarwinds-apm/ otel_wrapper.rb
fi
