# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'net/http'
require 'uri'
require 'json'

module SolarWindsAPM
  # ResourceDetector
  # Usage:
  #   require 'opentelemetry/sdk'
  #   require 'opentelemetry/resource/detector'
  #   OpenTelemetry::SDK.configure do |c|
  #     c.resource = SolarWindsAPM::ResourceDetector.detect
  #   end
  module ResourceDetector
    K8S_PODNAME_PATH = '/etc/hostname'
    K8S_NAMESPACE_PATH = '/var/run/secrets/kubernetes.io/serviceaccount/namespace'
    K8S_TOKEN_PATH = '/var/run/secrets/kubernetes.io/serviceaccount/token'

    UAMS_CLIENT_PATH = '/opt/solarwinds/uamsclient/var/uamsclientid'
    UAMS_CLIENT_URL = 'http://127.0.0.1:2113/info/uamsclient'
    UAMS_CLIENT_ID_FIELD = 'uamsclient_id'

    def self.detect
      attributes = ::OpenTelemetry::SDK::Resources::Resource.create({})
      attributes = attributes.merge(detect_uams_client_id)
      attributes = attributes.merge(detect_k8s_atttributes)
      attributes.merge(from_upstream_detector)
    end

    def self.detect_uams_client_id
      uams_client_id = nil
      if File.exist?(UAMS_CLIENT_PATH)
        uams_client_id = File.read(UAMS_CLIENT_PATH).strip
      else
        url = URI(UAMS_CLIENT_URL)

        response = nil
        ::OpenTelemetry::Common::Utilities.untraced do
          http = Net::HTTP.new(url.host, url.port)
          request = Net::HTTP::Get.new(url)
          response = http.request(request)
        end

        if response&.code.to_i == 200
          uams_metadata = JSON.parse(response.body)
          uams_client_id = uams_metadata&.fetch(UAMS_CLIENT_ID_FIELD)
        end
      end

      resource_attributes = {
        'sw.uams.client.id' => uams_client_id
      }

      ::OpenTelemetry::SDK::Resources::Resource.create(resource_attributes)
    rescue StandardError => e
      SolarWindsAPM.logger.debug "#{self.class}/#{__method__}] detect_uams_client_id failed. Error: #{e.message}."
      ::OpenTelemetry::SDK::Resources::Resource.create({})
    end

    def self.detect_k8s_atttributes
      return ::OpenTelemetry::SDK::Resources::Resource.create({}) unless ENV['KUBERNETES_SERVICE_HOST'] && ENV['KUBERNETES_SERVICE_PORT']

      resource_attributes = {}
      pod_name = File.read(K8S_PODNAME_PATH).strip if File.exist?(K8S_PODNAME_PATH)
      namespace = File.read(K8S_NAMESPACE_PATH).strip if File.exist?(K8S_NAMESPACE_PATH)
      pod_uid = nil
      token = nil

      token = File.read(K8S_TOKEN_PATH).strip if File.exist?(K8S_TOKEN_PATH)

      if token && pod_name && namespace
        url = URI("https://kubernetes.default.svc/api/v1/namespaces/#{namespace}/pods/#{pod_name}")

        response = nil
        ::OpenTelemetry::Common::Utilities.untraced do
          http = Net::HTTP.new(url.host, url.port)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER

          request = Net::HTTP::Get.new(url)
          request['Authorization'] = "Bearer #{token}"
          request['Accept'] = 'application/json'

          response = http.request(request)
        end

        if response&.code.to_i == 200
          pod_metadata = JSON.parse(response.body)
          pod_uid = pod_metadata&.fetch('metadata')&.fetch('uid')
        end
      end

      resource_attributes['k8s.namespace.name'] = namespace
      resource_attributes['k8s.pod.name'] = pod_name
      resource_attributes['k8s.pod.uid'] = pod_uid

      resource_attributes.compact!
      ::OpenTelemetry::SDK::Resources::Resource.create(resource_attributes)
    end

    def self.from_upstream_detector
      require_detector('opentelemetry-resource-detector-google_cloud_platform')
      require_detector('opentelemetry-resource-detector-container')
      require_detector('opentelemetry-resource-detector-azure')

      resource_attributes = ::OpenTelemetry::SDK::Resources::Resource.create({})
      resource_attributes = resource_attributes.merge(::OpenTelemetry::Resource::Detector::Azure.detect) if defined? OpenTelemetry::Resource::Detector::Azure
      resource_attributes = resource_attributes.merge(::OpenTelemetry::Resource::Detector::GoogleCloudPlatform.detect) if defined? OpenTelemetry::Resource::Detector::GoogleCloudPlatform
      resource_attributes = resource_attributes.merge(::OpenTelemetry::Resource::Detector::Container.detect) if defined? OpenTelemetry::Resource::Detector::Container

      SolarWindsAPM.logger.debug { "#{self.class}/#{__method__}] resource_attributes: #{resource_attributes.inspect}" }

      resource_attributes
    end

    def self.require_detector(gem_name)
      require gem_name
    rescue StandardError
      SolarWindsAPM.logger.warn { "No #{gem_name} found." }
    end
  end
end
