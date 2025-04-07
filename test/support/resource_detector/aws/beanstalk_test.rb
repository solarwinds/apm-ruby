# frozen_string_literal: true

# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/support/resource_detector/aws/beanstalk'

describe 'AWS ECS Resource Detector Test' do
  let(:beanstalk_conf_dir) { '/var/elasticbeanstalk/xray' }
  let(:beanstalk_conf_path) { '/var/elasticbeanstalk/xray/environment.conf' }

  before do
    unless File.exist?(beanstalk_conf_path)
      FileUtils.mkdir_p(beanstalk_conf_dir)
      File.open(beanstalk_conf_path, 'w') do |file|
        file.puts 'beanstalk'
      end
    end
  end

  it 'returns empty beanstalk attributes if the conf file is malformat' do
    attributes = SolarWindsAPM::ResourceDetector::Beanstalk.detect
    attribute_hash = attributes.instance_variable_get(:@attributes)

    _(attributes).must_be_instance_of(OpenTelemetry::SDK::Resources::Resource)
    assert_equal(attribute_hash, {})
  end
end
