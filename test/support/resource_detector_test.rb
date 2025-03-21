# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'webmock'
require './lib/solarwinds_apm/support/resource_detector'

describe 'Resource Detector Test' do
  it 'detect_k8s_atttributes_with_valid_path' do
    ENV['KUBERNETES_SERVICE_HOST'] = '10.96.0.1'
    ENV['KUBERNETES_SERVICE_PORT'] = '443'

    FileUtils.mkdir_p('/var/run/secrets/kubernetes.io/serviceaccount/')
    File.open(SolarWindsAPM::ResourceDetector::K8S_NAMESPACE_PATH, 'w') do |file|
      file.puts('fake_namespace')
    end
    File.open(SolarWindsAPM::ResourceDetector::K8S_TOKEN_PATH, 'w') do |file|
      file.puts('fake@token')
    end

    original_hostname = (File.read(SolarWindsAPM::ResourceDetector::K8S_PODNAME_PATH).strip! if File.exist?(SolarWindsAPM::ResourceDetector::K8S_PODNAME_PATH))

    File.open(SolarWindsAPM::ResourceDetector::K8S_PODNAME_PATH, 'w') do |file|
      file.puts('fake_hostname')
    end

    WebMock.disable_net_connect!
    WebMock.enable!
    WebMock.stub_request(:get, 'https://kubernetes.default.svc/api/v1/namespaces/fake_namespace/pods/fake_hostname')
           .to_return(
             status: 200,
             body: { 'kind' => 'Pod', 'metadata' => { 'uid' => 'fake_uid' } }.to_json,
             headers: { 'Content-Type' => 'application/json' }
           )
    attributes = SolarWindsAPM::ResourceDetector.detect_k8s_atttributes

    _(attributes.instance_variable_get(:@attributes)['k8s.namespace.name']).must_equal 'fake_namespace'
    _(attributes.instance_variable_get(:@attributes)['k8s.pod.name']).must_equal 'fake_hostname'
    _(attributes.instance_variable_get(:@attributes)['k8s.pod.uid']).must_equal 'fake_uid'

    File.delete(SolarWindsAPM::ResourceDetector::K8S_NAMESPACE_PATH)
    File.delete(SolarWindsAPM::ResourceDetector::K8S_TOKEN_PATH)
    if original_hostname.nil?
      File.delete(SolarWindsAPM::ResourceDetector::K8S_PODNAME_PATH)
    else
      File.open(SolarWindsAPM::ResourceDetector::K8S_PODNAME_PATH, 'w') do |file|
        file.puts(original_hostname)
      end
    end

    ENV.delete('KUBERNETES_SERVICE_HOST')
    ENV.delete('KUBERNETES_SERVICE_PORT')
    WebMock.reset!
    WebMock.allow_net_connect!
  end

  it 'detect_k8s_atttributes_with_invalid_path' do
    ENV['KUBERNETES_SERVICE_HOST'] = '10.96.0.1'
    ENV['KUBERNETES_SERVICE_PORT'] = '443'

    attributes = SolarWindsAPM::ResourceDetector.detect_k8s_atttributes
    assert_nil(attributes.instance_variable_get(:@attributes)['k8s.pod.uid'])
    assert_nil(attributes.instance_variable_get(:@attributes)['k8s.namespace.name'])

    ENV.delete('KUBERNETES_SERVICE_HOST')
    ENV.delete('KUBERNETES_SERVICE_PORT')
  end

  it 'return_empty_if_not_in_k8s' do
    attributes = SolarWindsAPM::ResourceDetector.detect_k8s_atttributes
    assert_equal(attributes.instance_variable_get(:@attributes), {})
  end

  it 'detect_uams_client_id_failed' do
    attributes = SolarWindsAPM::ResourceDetector.detect_uams_client_id
    assert_nil(attributes.instance_variable_get(:@attributes)['sw.uams.client.id'])
  end

  it 'detect_uams_client_id_from_file' do
    FileUtils.mkdir_p('/opt/solarwinds/uamsclient/var')
    File.open(SolarWindsAPM::ResourceDetector::UAMS_CLIENT_PATH, 'w') do |file|
      file.puts('fake_uams_client_id')
    end

    attributes = SolarWindsAPM::ResourceDetector.detect_uams_client_id

    _(attributes.instance_variable_get(:@attributes)['sw.uams.client.id']).must_equal 'fake_uams_client_id'
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
    WebMock.reset!
    WebMock.allow_net_connect!
  end
end
