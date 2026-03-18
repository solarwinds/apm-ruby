# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'webmock'
require './lib/solarwinds_apm/support/resource_detector'

describe 'Resource Detector Test' do
  let(:mount_file) { SolarWindsAPM::ResourceDetector::K8S_MOUNTINFO_FILE }
  it 'detects namespace, pod UID, and pod name when K8s env and files are present' do
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

  it 'detects pod name even when namespace file path is invalid' do
    ENV['KUBERNETES_SERVICE_HOST'] = '10.96.0.1'
    ENV['KUBERNETES_SERVICE_PORT'] = '443'

    attributes = SolarWindsAPM::ResourceDetector.detect_k8s_attributes
    attributes_hash = attributes.instance_variable_get(:@attributes)

    assert(attributes_hash['k8s.pod.name'])

    ENV.delete('KUBERNETES_SERVICE_HOST')
    ENV.delete('KUBERNETES_SERVICE_PORT')
  end

  it 'returns empty attributes when Kubernetes env vars are not set' do
    ENV.delete('KUBERNETES_SERVICE_HOST')
    ENV.delete('KUBERNETES_SERVICE_PORT')
    ENV.delete('SW_K8S_POD_NAME')
    ENV.delete('SW_K8S_POD_NAMESPACE')
    ENV.delete('SW_K8S_POD_UID')

    attributes = SolarWindsAPM::ResourceDetector.detect_k8s_attributes
    assert_equal(attributes.instance_variable_get(:@attributes), {})
  end

  it 'returns nil for uams client id when no source is available' do
    attributes = SolarWindsAPM::ResourceDetector.detect_uams_client_id
    assert_nil(attributes.instance_variable_get(:@attributes)['sw.uams.client.id'])
    assert_nil(attributes.instance_variable_get(:@attributes)['host.id'])
  end

  it 'reads UAMS client ID and host ID from file when file exists' do
    FileUtils.mkdir_p('/opt/solarwinds/uamsclient/var')
    File.open(SolarWindsAPM::ResourceDetector::UAMS_CLIENT_PATH, 'w') do |file|
      file.puts('fake_uams_client_id')
    end

    attributes = SolarWindsAPM::ResourceDetector.detect_uams_client_id

    _(attributes.instance_variable_get(:@attributes)['sw.uams.client.id']).must_equal 'fake_uams_client_id'
    _(attributes.instance_variable_get(:@attributes)['host.id']).must_equal 'fake_uams_client_id'
    File.delete(SolarWindsAPM::ResourceDetector::UAMS_CLIENT_PATH)
  end

  it 'fetches UAMS client ID from local HTTP endpoint when file is unavailable' do
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

  describe 'detect' do
    it 'returns resource with uuid attribute' do
      WebMock.enable!
      WebMock.stub_request(:get, SolarWindsAPM::ResourceDetector::UAMS_CLIENT_URL)
             .to_return(status: 500, body: '')
      # Stub all requests to AWS/Azure metadata service
      WebMock.stub_request(:any, /169\.254\.169\.254/)
             .to_return(status: 408, body: '')

      ENV.delete('KUBERNETES_SERVICE_HOST')
      ENV.delete('KUBERNETES_SERVICE_PORT')

      result = SolarWindsAPM::ResourceDetector.detect
      attrs = result.instance_variable_get(:@attributes)

      assert attrs.key?('service.instance.id')
      refute_nil attrs['service.instance.id']
    ensure
      WebMock.disable!
    end
  end

  describe 'detect_uams_client_id' do
    it 'handles API failure gracefully' do
      WebMock.enable!
      WebMock.stub_request(:get, SolarWindsAPM::ResourceDetector::UAMS_CLIENT_URL)
             .to_return(status: 500, body: 'error')

      stub_const = SolarWindsAPM::ResourceDetector
      original_path = stub_const.const_get(:UAMS_CLIENT_PATH)
      stub_const.send(:remove_const, :UAMS_CLIENT_PATH)
      stub_const.const_set(:UAMS_CLIENT_PATH, '/nonexistent/path/uamsclientid')

      result = stub_const.detect_uams_client_id
      attrs = result.instance_variable_get(:@attributes)

      assert_nil attrs['sw.uams.client.id']
    ensure
      stub_const.send(:remove_const, :UAMS_CLIENT_PATH)
      stub_const.const_set(:UAMS_CLIENT_PATH, original_path)
      WebMock.disable!
    end
  end

  describe 'detect_k8s_attributes' do
    it 'reads pod name from env variable' do
      ENV['KUBERNETES_SERVICE_HOST'] = '10.96.0.1'
      ENV['KUBERNETES_SERVICE_PORT'] = '443'
      ENV['SW_K8S_POD_NAME'] = 'my-pod-name'

      result = SolarWindsAPM::ResourceDetector.detect_k8s_attributes
      attrs = result.instance_variable_get(:@attributes)

      assert_equal 'my-pod-name', attrs['k8s.pod.name']
    ensure
      ENV.delete('KUBERNETES_SERVICE_HOST')
      ENV.delete('KUBERNETES_SERVICE_PORT')
      ENV.delete('SW_K8S_POD_NAME')
    end

    it 'reads pod namespace from env variable' do
      ENV['KUBERNETES_SERVICE_HOST'] = '10.96.0.1'
      ENV['KUBERNETES_SERVICE_PORT'] = '443'
      ENV['SW_K8S_POD_NAMESPACE'] = 'test-namespace'

      result = SolarWindsAPM::ResourceDetector.detect_k8s_attributes
      attrs = result.instance_variable_get(:@attributes)

      assert_equal 'test-namespace', attrs['k8s.namespace.name']
    ensure
      ENV.delete('KUBERNETES_SERVICE_HOST')
      ENV.delete('KUBERNETES_SERVICE_PORT')
      ENV.delete('SW_K8S_POD_NAMESPACE')
    end
  end

  describe 'detect_ec2' do
    it 'returns resource without raising' do
      result = SolarWindsAPM::ResourceDetector.detect_ec2
      refute_nil result
    end
  end

  describe 'detect_azure' do
    it 'returns resource without raising' do
      result = SolarWindsAPM::ResourceDetector.detect_azure
      refute_nil result
    end
  end

  describe 'detect_container' do
    it 'returns resource without raising' do
      result = SolarWindsAPM::ResourceDetector.detect_container
      refute_nil result
    end
  end

  describe 'number?' do
    it 'returns true for valid numbers' do
      assert SolarWindsAPM::ResourceDetector.number?('42')
      assert SolarWindsAPM::ResourceDetector.number?('3.14')
      assert SolarWindsAPM::ResourceDetector.number?('-1')
    end

    it 'returns false for non-numbers' do
      refute SolarWindsAPM::ResourceDetector.number?('abc')
      refute SolarWindsAPM::ResourceDetector.number?('')
    end
  end

  describe 'safe_integer?' do
    it 'returns true for safe integers' do
      assert SolarWindsAPM::ResourceDetector.safe_integer?(42)
      assert SolarWindsAPM::ResourceDetector.safe_integer?(0)
      assert SolarWindsAPM::ResourceDetector.safe_integer?(-100)
      assert SolarWindsAPM::ResourceDetector.safe_integer?('123')
    end

    it 'returns false for unsafe integers' do
      refute SolarWindsAPM::ResourceDetector.safe_integer?(2**53)
      refute SolarWindsAPM::ResourceDetector.safe_integer?(-(2**53))
    end
  end

  describe 'windows?' do
    it 'returns false on non-windows platforms' do
      refute SolarWindsAPM::ResourceDetector.windows? unless RUBY_PLATFORM.match?(/mswin|mingw|cygwin/)
    end
  end

  describe 'random_uuid' do
    it 'returns a valid UUID string' do
      uuid = SolarWindsAPM::ResourceDetector.random_uuid
      assert_match(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/, uuid)
    end

    it 'returns unique values' do
      uuid1 = SolarWindsAPM::ResourceDetector.random_uuid
      uuid2 = SolarWindsAPM::ResourceDetector.random_uuid
      refute_equal uuid1, uuid2
    end
  end

  describe 'run_opentelemetry_detector' do
    it 'handles detector failure gracefully' do
      # Create a mock detector that raises
      mock_detector = Class.new do
        def self.detect
          raise StandardError, 'detector failed'
        end
      end

      result = SolarWindsAPM::ResourceDetector.run_opentelemetry_detector(mock_detector)
      attrs = result.instance_variable_get(:@attributes)
      assert_empty attrs
    end
  end
end
