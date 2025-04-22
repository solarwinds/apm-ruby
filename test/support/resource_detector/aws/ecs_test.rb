# frozen_string_literal: true

# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'webmock'
require 'webmock/minitest'
require './lib/solarwinds_apm/support/resource_detector/aws/ecs'

describe 'AWS ECS Resource Detector Test' do
  puts "\n\033[1m=== TEST RUN ECS TEST: #{RUBY_VERSION} #{File.basename(__FILE__)} #{Time.now.strftime('%Y-%m-%d %H:%M')} ===\033[0m\n"

  let(:cgroup_path) { '/proc/self/cgroup' }
  let(:sample_json) { ECS_SAMPLE_JSON }
  let(:sample_task) { ECS_SAMPLE_TASK }

  let(:expected_resource_attributes) do
    { 'cloud.provider' => 'aws',
      'cloud.platform' => 'aws_ecs',
      'aws.ecs.cluster.arn' => 'arn:aws:ecs:us-east-1:123456789012:cluster/MyEmptyCluster',
      'aws.ecs.launchtype' => 'FARGATE',
      'aws.ecs.task.arn' => 'arn:aws:ecs:us-east-1:123456789012:task/MyEmptyCluster/bfa2636268144d039771334145e490c5',
      'aws.ecs.task.family' => 'sample-fargate',
      'aws.ecs.task.revision' => '5',
      'cloud.account.id' => '123456789012',
      'cloud.region' => 'us-east-1',
      'cloud.availability_zone' => 'us-east-1d',
      'cloud.resource_id' => 'arn:aws:ecs:us-west-2:111122223333:container/05966557-f16c-49cb-9352-24b3a0dcd0e1',
      'aws.ecs.container.arn' => 'arn:aws:ecs:us-west-2:111122223333:container/05966557-f16c-49cb-9352-24b3a0dcd0e1',
      'aws.log.group.names' => ['us-west-2'],
      'aws.log.group.arns' => ['arn:aws:logs:us-west-2:111122223333:log-group:us-west-2'],
      'aws.log.stream.names' => ['ecs/curl/cd189a933e5849daa93386466019ab50'],
      'aws.log.stream.arns' => ['arn:aws:logs:us-west-2:111122223333:log-group:us-west-2:log-stream:ecs/curl/cd189a933e5849daa93386466019ab50'] }
  end

  before do
    WebMock.disable_net_connect!

    unless File.exist?(cgroup_path)
      File.open(cgroup_path, 'w') do |file|
        file.puts '0::/'
      end
    end
  end

  after do
    WebMock.reset!
    WebMock.allow_net_connect!
    ENV.delete('ECS_CONTAINER_METADATA_URI_V4')
  end

  it 'return empty resource attributes if not in ecs env' do
    attributes = SolarWindsAPM::ResourceDetector::ECS.detect
    attribute_hash = attributes.instance_variable_get(:@attributes)

    _(attributes).must_be_instance_of(OpenTelemetry::SDK::Resources::Resource)
    assert_equal(attribute_hash, {})
  end

  it 'returns a resource with ECS attributes' do
    ENV['ECS_CONTAINER_METADATA_URI_V4'] = 'http://169.254.170.2/v4/abcd1234-5678-90ef-ghij-klmnopqrstuv'
    # Stub token request
    stub_request(:get, 'http://169.254.170.2/v4/abcd1234-5678-90ef-ghij-klmnopqrstuv')
      .to_return(status: 200, body: sample_json.to_json)

    stub_request(:get, 'http://169.254.170.2/v4/abcd1234-5678-90ef-ghij-klmnopqrstuv/task')
      .to_return(status: 200, body: sample_task.to_json)

    attributes = SolarWindsAPM::ResourceDetector::ECS.detect
    attribute_hash = attributes.instance_variable_get(:@attributes)

    _(attributes).must_be_instance_of(OpenTelemetry::SDK::Resources::Resource)
    assert(attribute_hash['host.name'])
    expected_resource_attributes['host.name'] = attribute_hash['host.name']
    assert_equal(attribute_hash, expected_resource_attributes)
  end

  it 'returns a resource with ECS attributes without valid container metadata' do
    ENV['ECS_CONTAINER_METADATA_URI_V4'] = 'http://169.254.170.2/v4/abcd1234-5678-90ef-ghij-klmnopqrstuv'
    # Stub token request
    stub_request(:get, 'http://169.254.170.2/v4/abcd1234-5678-90ef-ghij-klmnopqrstuv')
      .to_return(status: 403, body: 'Forbidden')

    stub_request(:get, 'http://169.254.170.2/v4/abcd1234-5678-90ef-ghij-klmnopqrstuv/task')
      .to_return(status: 200, body: sample_task.to_json)

    attributes = SolarWindsAPM::ResourceDetector::ECS.detect
    attribute_hash = attributes.instance_variable_get(:@attributes)

    ['cloud.resource_id',
     'aws.ecs.container.arn',
     'aws.log.group.names',
     'aws.log.group.arns',
     'aws.log.stream.names',
     'aws.log.stream.arns'].each do |key|
      expected_resource_attributes.delete(key)
    end

    _(attributes).must_be_instance_of(OpenTelemetry::SDK::Resources::Resource)
    assert(attribute_hash['host.name'])
    expected_resource_attributes['host.name'] = attribute_hash['host.name']
    assert_equal(attribute_hash, expected_resource_attributes)
  end

  it 'returns a resource with ECS attributes without valid task metadata' do
    ENV['ECS_CONTAINER_METADATA_URI_V4'] = 'http://169.254.170.2/v4/abcd1234-5678-90ef-ghij-klmnopqrstuv'
    # Stub token request
    stub_request(:get, 'http://169.254.170.2/v4/abcd1234-5678-90ef-ghij-klmnopqrstuv')
      .to_return(status: 200, body: sample_json.to_json)

    stub_request(:get, 'http://169.254.170.2/v4/abcd1234-5678-90ef-ghij-klmnopqrstuv/task')
      .to_return(status: 403, body: 'Forbidden')

    attributes = SolarWindsAPM::ResourceDetector::ECS.detect
    attribute_hash = attributes.instance_variable_get(:@attributes)

    ['aws.ecs.cluster.arn',
     'aws.ecs.launchtype',
     'aws.ecs.task.arn',
     'aws.ecs.task.family',
     'aws.ecs.task.revision',
     'cloud.account.id',
     'cloud.region',
     'cloud.availability_zone'].each do |key|
      expected_resource_attributes.delete(key)
    end

    _(attributes).must_be_instance_of(OpenTelemetry::SDK::Resources::Resource)
    assert(attribute_hash['host.name'])
    expected_resource_attributes['host.name'] = attribute_hash['host.name']
    assert_equal(attribute_hash, expected_resource_attributes)
  end
end
