#!/usr/bin/env sh
# Copyright (c) SolarWinds, LLC.
# All rights reserved.

# setup the system

install_ruby() {
  git clone https://github.com/rbenv/rbenv.git ~/.rbenv \
    && git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build \
    && git clone https://github.com/rbenv/rbenv-default-gems.git ~/.rbenv/plugins/rbenv-default-gems \
    && echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.profile \
    && echo 'eval "$(rbenv init -)"' >> ~/.profile \
    && echo 'eval "$(rbenv init -)"' >> ~/.bashrc \
    && echo 'bundler' > ~/.rbenv/default-gems

  if [ ! -z "$RUBY_VERSION" ]; then {
    . ~/.profile && rbenv install "$RUBY_VERSION"
    rbenv local "$RUBY_VERSION"
  }
  else {
    . ~/.profile && rbenv install 3.1.0
    rbenv local 3.1.0
  }
  fi 
}

echo "Start Run Setup"

pretty_name=$(grep PRETTY_NAME /etc/os-release | sed 's/PRETTY_NAME="//' | sed 's/"//')
if [ -r /etc/alpine-release ]; then
  apk update && apk add --upgrade git ruby-dev g++ make curl bash perl zlib-dev linux-headers shared-mime-info sqlite-dev grpc
elif [ -r /etc/debian_version ]; then
  # this is for ubuntu (> 22.04) and debian
  apt-get update && apt-get install -y git ruby-dev g++ make curl zlib1g-dev shared-mime-info
elif [ "$pretty_name" = "Amazon Linux 2" ]; then
  amazon-linux-extras install epel -y
  yum update && yum install -y ruby-devel gcc-c++ make openssl-devel shared-mime-info git zlib-devel tar curl sqlite-devel
elif [ "$pretty_name" = "Amazon Linux 2023" ]; then
  yum update && yum install -y --skip-broken ruby-devel gcc-c++ make openssl-devel shared-mime-info git zlib-devel tar curl sqlite-devel
fi

install_ruby

echo "Finished Setup"

if [ ! -z "$RUBY_VERSION" ]; then {
  # If there is version provide, then run the test
  echo "Start Run Unit Test"
  mkdir log
  test/run_otel_tests/run_tests.sh -r "$RUBY_VERSION"
  echo "Finished Unit Test"
}
fi
