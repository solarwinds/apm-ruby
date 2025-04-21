# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'webmock'
require './lib/solarwinds_apm/support/resource_detector'

describe 'Resource Detector Test' do
  let(:mount_file) { SolarWindsAPM::ResourceDetector::K8S_MOUNTINFO_FILE }
  it 'detect_k8s_attributes_with_valid_path' do
    ENV['KUBERNETES_SERVICE_HOST'] = '10.96.0.1'
    ENV['KUBERNETES_SERVICE_PORT'] = '443'
    # can't modify the /proc/self/mountinfo inside docker, use env for testing
    ENV['SW_K8S_POD_UID'] = 'b4683374-c415-4136-99bf-7fd72a0aa885'

    FileUtils.mkdir_p('/var/run/secrets/kubernetes.io/serviceaccount/')
    File.open(SolarWindsAPM::ResourceDetector::K8S_NAMESPACE_PATH, 'w') do |file|
      file.puts('fake_namespace')
    end

    attributes = SolarWindsAPM::ResourceDetector.detect_k8s_attributes
    attributes_hash = attributes.instance_variable_get(:@attributes)

    _(attributes_hash['k8s.namespace.name']).must_equal 'fake_namespace'
    _(attributes_hash['k8s.pod.uid']).must_equal 'b4683374-c415-4136-99bf-7fd72a0aa885'
    assert(attributes_hash['k8s.pod.name'])

    File.delete(SolarWindsAPM::ResourceDetector::K8S_NAMESPACE_PATH)

    ENV.delete('KUBERNETES_SERVICE_HOST')
    ENV.delete('KUBERNETES_SERVICE_PORT')
    ENV.delete('SW_K8S_POD_UID')
  end

  it 'detect_k8s_attributes_with_invalid_path' do
    ENV['KUBERNETES_SERVICE_HOST'] = '10.96.0.1'
    ENV['KUBERNETES_SERVICE_PORT'] = '443'

    attributes = SolarWindsAPM::ResourceDetector.detect_k8s_attributes
    attributes_hash = attributes.instance_variable_get(:@attributes)

    assert(attributes_hash['k8s.pod.name'])

    ENV.delete('KUBERNETES_SERVICE_HOST')
    ENV.delete('KUBERNETES_SERVICE_PORT')
  end

  it 'return_empty_if_not_in_k8s' do
    attributes = SolarWindsAPM::ResourceDetector.detect_k8s_attributes
    assert_equal(attributes.instance_variable_get(:@attributes), {})
  end

  it 'detect_uams_client_id_failed' do
    attributes = SolarWindsAPM::ResourceDetector.detect_uams_client_id
    assert_nil(attributes.instance_variable_get(:@attributes)['sw.uams.client.id'])
    assert_nil(attributes.instance_variable_get(:@attributes)['host.id'])
  end

  it 'detect_uams_client_id_from_file' do
    FileUtils.mkdir_p('/opt/solarwinds/uamsclient/var')
    File.open(SolarWindsAPM::ResourceDetector::UAMS_CLIENT_PATH, 'w') do |file|
      file.puts('fake_uams_client_id')
    end

    attributes = SolarWindsAPM::ResourceDetector.detect_uams_client_id

    _(attributes.instance_variable_get(:@attributes)['sw.uams.client.id']).must_equal 'fake_uams_client_id'
    _(attributes.instance_variable_get(:@attributes)['host.id']).must_equal 'fake_uams_client_id'
    File.delete(SolarWindsAPM::ResourceDetector::UAMS_CLIENT_PATH)
  end

  it 'detect_uams_client_id_from_local_url' do
    WebMock.disable_net_connect!
    WebMock.enable!
    WebMock.stub_request(:get, SolarWindsAPM::ResourceDetector::UAMS_CLIENT_URL)
           .to_return(
             status: 200,
             body: { SolarWindsAPM::ResourceDetector::UAMS_CLIENT_ID_FIELD => '12345', 'status' => 'active' }.to_json,
             headers: { 'Content-Type' => 'application/json' }
           )

    attributes = SolarWindsAPM::ResourceDetector.detect_uams_client_id
    _(attributes.instance_variable_get(:@attributes)['sw.uams.client.id']).must_equal '12345'
    _(attributes.instance_variable_get(:@attributes)['host.id']).must_equal '12345'
    WebMock.reset!
    WebMock.allow_net_connect!
  end

  # it '' do
  #   assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/, attributes_hash['service.instance.id'])
  # end
end
