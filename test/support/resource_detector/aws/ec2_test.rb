# frozen_string_literal: true

# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'webmock'
require 'webmock/minitest'
require './lib/solarwinds_apm/support/resource_detector/aws/ec2'

describe 'AWS EC2 Resource Detector Test' do
  puts "\n\033[1m=== TEST RUN EC2 TEST: #{RUBY_VERSION} #{File.basename(__FILE__)} #{Time.now.strftime('%Y-%m-%d %H:%M')} ===\033[0m\n"

  let(:ec2_metadata_host) { '169.254.169.254' }
  let(:token_path) { '/latest/api/token' }
  let(:identity_document_path) { '/latest/dynamic/instance-identity/document' }
  let(:hostname_path) { '/latest/meta-data/hostname' }
  let(:mock_token) { 'mock-token-123456' }
  let(:mock_identity_document) { EC2_IDENTITY_DOC }
  let(:mock_hostname) { 'ip-172-12-34-567.mock-west-2.compute.internal' }
  let(:expected_resource_attributes) do
    {
      'cloud.provider' => 'aws',
      'cloud.platform' => 'aws_ec2',
      'cloud.account.id' => '123456789012',
      'cloud.region' => 'mock-west-2',
      'cloud.availability_zone' => 'mock-west-2a',
      'host.id' => 'i-1234ab56cd7e89f01',
      'host.type' => 't2.micro-mock',
      'host.name' => 'ip-172-12-34-567.mock-west-2.compute.internal'
    }
  end

  before do
    WebMock.disable_net_connect!

    # Stub token request
    stub_request(:put, "http://#{ec2_metadata_host}#{token_path}")
      .with(headers: { 'X-aws-ec2-metadata-token-ttl-seconds' => '60' })
      .to_return(status: 200, body: mock_token)

    # Stub identity document request
    stub_request(:get, "http://#{ec2_metadata_host}#{identity_document_path}")
      .with(headers: { 'X-aws-ec2-metadata-token' => mock_token })
      .to_return(status: 200, body: mock_identity_document.to_json)

    # Stub hostname request
    stub_request(:get, "http://#{ec2_metadata_host}#{hostname_path}")
      .with(headers: { 'X-aws-ec2-metadata-token' => mock_token })
      .to_return(status: 200, body: mock_hostname)
  end

  after do
    WebMock.reset!
    WebMock.allow_net_connect!
  end

  it 'returns a resource with EC2 attributes' do
    attributes = SolarWindsAPM::ResourceDetector::EC2.detect
    attribute_hash = attributes.instance_variable_get(:@attributes)

    _(attributes).must_be_instance_of(OpenTelemetry::SDK::Resources::Resource)
    assert_equal(attribute_hash, expected_resource_attributes)
  end

  it 'when token request returns error code in IMDSv2, identity is nil' do
    # Stub token request
    stub_request(:put, "http://#{ec2_metadata_host}#{token_path}")
      .with(headers: { 'X-aws-ec2-metadata-token-ttl-seconds' => '60' })
      .to_return(status: 403, body: 'Forbidden')

    stub_request(:get, "http://#{ec2_metadata_host}#{identity_document_path}")
      .to_return(status: 403, body: 'Forbidden')

    stub_request(:get, "http://#{ec2_metadata_host}#{hostname_path}")
      .to_return(status: 403, body: 'Forbidden')

    attributes = SolarWindsAPM::ResourceDetector::EC2.detect
    attribute_hash = attributes.instance_variable_get(:@attributes)

    assert_equal(attribute_hash, { 'cloud.provider' => 'aws', 'cloud.platform' => 'aws_ec2' })
  end
end
