# Copyright (c) SolarWinds, LLC.
# All rights reserved.

# setup the system
if [[ -r /etc/alpine-release ]]; then
  apk update && apk add --upgrade ruby-dev g++ make
elif [[ -r /etc/debian_version ]]; then
  apt-get update && apt-get install -y ruby-dev g++ make
fi

# install gem
if [ "$MODE" = "RubyGem" ]; then
  echo "RubyGem"
  gem install solarwinds_apm -v "$SOLARWINDS_APM_VERSION"
elif [ "$MODE" = "packagecloud" ]; then
  echo "packagecloud"
  gem install solarwinds_apm -v "$SOLARWINDS_APM_VERSION" --source https://packagecloud.io/solarwinds/solarwinds-apm-otel-ruby/
fi

# verification
ruby ./scripts/test_install.rb

if [[ $? -ne 0 ]]
  echo "Problem encountered"
  exit 1
fi

exit 0