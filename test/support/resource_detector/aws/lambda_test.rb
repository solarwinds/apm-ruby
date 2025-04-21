# frozen_string_literal: true

# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/support/resource_detector/aws/lambda'

describe 'AWS Lambda Resource Detector Test' do
  let(:expected_attributes) do
    { 'cloud.provider' => 'aws', 'cloud.platform' => 'aws_lambda', 'cloud.region' => 'us-west-2', 'faas.name' => 'my_lambda_function', 'faas.version' => '1', 'faas.max_memory' => 134_217_728, 'aws.log.group.names' => ['/aws/lambda/my_lambda_function'], 'faas.instance' => ['2024/03/30/[$LATEST]abcdefgh1234567890'] }
  end
  before do
    ENV['AWS_REGION'] = 'us-west-2'
    ENV['AWS_LAMBDA_FUNCTION_NAME'] = 'my_lambda_function'
    ENV['AWS_LAMBDA_FUNCTION_VERSION'] = '1'
    ENV['AWS_LAMBDA_FUNCTION_MEMORY_SIZE'] = '128'
    ENV['AWS_LAMBDA_LOG_GROUP_NAME'] = '/aws/lambda/my_lambda_function'
    ENV['AWS_LAMBDA_LOG_STREAM_NAME'] = '2024/03/30/[$LATEST]abcdefgh1234567890'
  end

  after do
    ENV.delete('AWS_REGION')
    ENV.delete('AWS_LAMBDA_FUNCTION_NAME')
    ENV.delete('AWS_LAMBDA_FUNCTION_VERSION')
    ENV.delete('AWS_LAMBDA_FUNCTION_MEMORY_SIZE')
    ENV.delete('AWS_LAMBDA_LOG_GROUP_NAME')
    ENV.delete('AWS_LAMBDA_LOG_STREAM_NAME')
    ENV.delete('AWS_EXECUTION_ENV')
  end

  it 'return empty attributes if not in lambda env' do
    attributes = SolarWindsAPM::ResourceDetector::Lambda.detect
    attribute_hash = attributes.instance_variable_get(:@attributes)

    _(attributes).must_be_instance_of(OpenTelemetry::SDK::Resources::Resource)
    assert_equal(attribute_hash, {})
  end

  it 'get simple lambda resource attributes' do
    ENV['AWS_EXECUTION_ENV'] = 'AWS_Lambda_abcd'

    attributes = SolarWindsAPM::ResourceDetector::Lambda.detect
    attribute_hash = attributes.instance_variable_get(:@attributes)

    _(attributes).must_be_instance_of(OpenTelemetry::SDK::Resources::Resource)
    assert_equal(attribute_hash, expected_attributes)
  end
end
