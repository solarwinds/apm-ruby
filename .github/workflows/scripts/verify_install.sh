# Copyright (c) SolarWinds, LLC.
# All rights reserved.

# setup the system
pretty_name=$(grep PRETTY_NAME /etc/os-release | sed 's/PRETTY_NAME="//' | sed 's/"//')
if [ -r /etc/alpine-release ]; then
  apk update && apk add --upgrade ruby-dev g++ make
elif [ -r /etc/debian_version ]; then
  # this is for ubuntu (> 22.04) and debian
  apt-get update && apt-get install -y ruby-dev g++ make
elif [ "$pretty_name" = "Amazon Linux 2" ]; then
  amazon-linux-extras install epel -y
  yes | yum update && yum install -y ruby-devel gcc-c++ make tar openssl-devel git
  git clone https://github.com/rbenv/rbenv.git ~/.rbenv \
    && git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build \
    && git clone https://github.com/rbenv/rbenv-default-gems.git ~/.rbenv/plugins/rbenv-default-gems \
    && echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.profile \
    && echo 'eval "$(rbenv init -)"' >> ~/.profile \
    && echo 'eval "$(rbenv init -)"' >> ~/.bashrc \
    && echo 'bundler' > ~/.rbenv/default-gems
  . ~/.profile && rbenv install 3.1.0
  rbenv local 3.1.0
elif [ "$pretty_name" = "Amazon Linux 2023" ]; then
  yum update && yum install -y ruby-devel gcc-c++ make tar openssl-devel git zlib-devel
  git clone https://github.com/rbenv/rbenv.git ~/.rbenv \
    && git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build \
    && git clone https://github.com/rbenv/rbenv-default-gems.git ~/.rbenv/plugins/rbenv-default-gems \
    && echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.profile \
    && echo 'eval "$(rbenv init -)"' >> ~/.profile \
    && echo 'eval "$(rbenv init -)"' >> ~/.bashrc \
    && echo 'bundler' > ~/.rbenv/default-gems
  . ~/.profile && rbenv install 3.1.0
  rbenv local 3.1.0
fi

# install gem
if [ "$MODE" = "RubyGem" ]; then
  echo "RubyGem"
  gem install solarwinds_apm -v "$SOLARWINDS_APM_VERSION"
elif [ "$MODE" = "GitHub" ]; then
  echo "GitHub"
  VERSION_LOWER_CASE=$(echo "$SOLARWINDS_APM_VERSION" | tr '[:upper:]' '[:lower:]')
  gem install solarwinds_apm -v "$VERSION_LOWER_CASE" --source https://rubygems.pkg.github.com/solarwinds
fi

# verification
echo "$PWD"
ruby test_install.rb

if [ $? -ne 0 ]; then
  echo "Problem encountered"
  exit 1
fi

exit 0