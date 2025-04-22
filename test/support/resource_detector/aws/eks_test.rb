# frozen_string_literal: true

# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'webmock'
require 'webmock/minitest'
require './lib/solarwinds_apm/support/resource_detector/aws/eks'

describe 'AWS EKS Resource Detector Test' do
  puts "\n\033[1m=== TEST RUN EKS TEST: #{RUBY_VERSION} #{File.basename(__FILE__)} #{Time.now.strftime('%Y-%m-%d %H:%M')} ===\033[0m\n"

  let(:k8s_svc_url) { 'kubernetes.default.svc' }
  let(:k8s_dir) { '/var/run/secrets/kubernetes.io/serviceaccount' }
  let(:k8s_token_path) { '/var/run/secrets/kubernetes.io/serviceaccount/token' }
  let(:k8s_cert_path) { '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt' }
  let(:auth_configmap_path) { '/api/v1/namespaces/kube-system/configmaps/aws-auth' }
  let(:cw_configmap_path) { '/api/v1/namespaces/amazon-cloudwatch/configmaps/cluster-info' }
  let(:cgroup_path) { '/proc/self/cgroup' }
  let(:token) { 'k8s_cred_header' }
  let(:cert) { 'abcd' }

  let(:config_map) { { 'test' => 'map' } }
  let(:cluster_map) { EKS_CLUSTER_MAP }

  before do
    WebMock.disable_net_connect!

    unless File.exist?(k8s_token_path)
      FileUtils.mkdir_p(k8s_dir)
      File.open(k8s_token_path, 'w') do |file|
        file.puts token
      end
    end

    unless File.exist?(k8s_cert_path)
      FileUtils.mkdir_p(k8s_dir)
      File.open(k8s_cert_path, 'w') do |file|
        file.puts cert
      end
    end
  end

  after do
    WebMock.reset!
    WebMock.allow_net_connect!
  end

  it 'returns empty resource with EKS attributes when failed' do
    stub_request(:get, "https://#{k8s_svc_url}#{auth_configmap_path}")
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(status: 403, body: '')

    stub_request(:get, "https://#{k8s_svc_url}#{cw_configmap_path}")
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(status: 403, body: '')

    attributes = SolarWindsAPM::ResourceDetector::EKS.detect
    attribute_hash = attributes.instance_variable_get(:@attributes)

    _(attributes).must_be_instance_of(OpenTelemetry::SDK::Resources::Resource)
    assert_equal(attribute_hash, {})
  end

  it 'returns resource with EKS attributes' do
    stub_request(:get, "https://#{k8s_svc_url}#{auth_configmap_path}")
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(status: 200, body: config_map.to_json)

    stub_request(:get, "https://#{k8s_svc_url}#{cw_configmap_path}")
      .with(headers: { 'Authorization' => "Bearer #{token}" })
      .to_return(status: 200, body: cluster_map.to_json)

    attributes = SolarWindsAPM::ResourceDetector::EKS.detect
    attribute_hash = attributes.instance_variable_get(:@attributes)

    _(attributes).must_be_instance_of(OpenTelemetry::SDK::Resources::Resource)
    assert_equal(attribute_hash, { 'cloud.provider' => 'aws', 'cloud.platform' => 'aws_eks', 'k8s.cluster.name' => 'my-eks-cluster' })
  end
end
