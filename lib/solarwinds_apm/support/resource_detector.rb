# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'net/http'
require 'uri'
require 'json'
require 'socket'
require 'securerandom'

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
    K8S_NAMESPACE_PATH_WIN = 'C:\\var\\run\\secrets\\kubernetes.io\\serviceaccount\\namespace'
    K8S_MOUNTINFO_FILE = '/proc/self/mountinfo'
    UID_REGEX = /[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}/i

    SW_K8S_NAMESPACE_ENV = 'SW_K8S_POD_NAMESPACE'
    SW_K8S_UID_ENV = 'SW_K8S_POD_UID'
    SW_K8S_NAME_ENV = 'SW_K8S_POD_NAME'

    UAMS_CLIENT_PATH = '/opt/solarwinds/uamsclient/var/uamsclientid'
    UAMS_CLIENT_PATH_WIN = 'C:\\ProgramData\\SolarWinds\\UAMSClient\\uamsclientid'
    UAMS_CLIENT_URL = 'http://127.0.0.1:2113/info/uamsclient'
    UAMS_CLIENT_ID_FIELD = 'uamsclient_id'

    def self.detect
      uuid_attr = { ::OpenTelemetry::SemanticConventions::Resource::SERVICE_INSTANCE_ID => random_uuid }
      attributes = ::OpenTelemetry::SDK::Resources::Resource.create(uuid_attr)
      attributes = attributes.merge(detect_uams_client_id)
      attributes = attributes.merge(detect_k8s_attributes)
      attributes.merge(from_upstream_detector)
    end

    def self.detect_uams_client_id
      uams_client_final_path = windows? ? UAMS_CLIENT_PATH_WIN : UAMS_CLIENT_PATH
      uams_client_id = nil
      begin
        uams_client_id = File.read(uams_client_final_path).strip
      rescue StandardError => e
        SolarWindsAPM.logger.debug "#{self.class}/#{__method__}] uams file retrieve error #{e.message}."
      end

      if uams_client_id.nil?
        begin
          url = URI(UAMS_CLIENT_URL)

          response = nil
          ::OpenTelemetry::Common::Utilities.untraced do
            http = Net::HTTP.new(url.host, url.port)
            request = Net::HTTP::Get.new(url)
            response = http.request(request)
          end

          raise 'Response returned non-200 status code' unless response&.code.to_i == 200

          uams_metadata = JSON.parse(response.body)
          uams_client_id = uams_metadata&.fetch(UAMS_CLIENT_ID_FIELD)
        rescue StandardError => e
          SolarWindsAPM.logger.debug "#{self.class}/#{__method__}] uams api retrieve error #{e.message}."
        end
      end

      resource_attributes = {
        'sw.uams.client.id' => uams_client_id,
        'host.id' => uams_client_id
      }

      SolarWindsAPM.logger.debug "#{self.class}/#{__method__}] retrieved resource_attributes: #{resource_attributes.inspect}."
      ::OpenTelemetry::SDK::Resources::Resource.create(resource_attributes)
    rescue StandardError => e
      SolarWindsAPM.logger.debug "#{self.class}/#{__method__}] detect_uams_client_id failed. Error: #{e.message}."
      ::OpenTelemetry::SDK::Resources::Resource.create({})
    end

    def self.detect_k8s_attributes
      unless ENV['KUBERNETES_SERVICE_HOST'] && ENV['KUBERNETES_SERVICE_PORT']
        SolarWindsAPM.logger.debug { "Can't read environment variable (KUBERNETES_SERVICE_HOST/KUBERNETES_SERVICE_PORT). It's likely not in kubernetes pod environment. No K8S resource detection." }
        return ::OpenTelemetry::SDK::Resources::Resource.create({})
      end

      pod_name = ENV.fetch(SW_K8S_NAME_ENV, nil)
      if pod_name.nil?
        pod_name = Socket.gethostname
      else
        SolarWindsAPM.logger.debug { "read pod name from env #{pod_name}" }
      end

      pod_namespace = ENV.fetch(SW_K8S_NAMESPACE_ENV, nil)
      if pod_namespace.nil?
        begin
          k8s_namspace_final_path = windows? ? K8S_NAMESPACE_PATH_WIN : K8S_NAMESPACE_PATH
          pod_namespace = File.read(k8s_namspace_final_path).strip
          SolarWindsAPM.logger.debug { 'read pod namespace from file' }
        rescue StandardError => e
          SolarWindsAPM.logger.debug { "can't read pod namespace #{e.message}" }
        end
      else
        SolarWindsAPM.logger.debug { "read pod namespace from env #{pod_namespace}" }
      end

      pod_uid = ENV.fetch(SW_K8S_UID_ENV, nil)
      if pod_uid.nil?
        begin
          File.open(K8S_MOUNTINFO_FILE) do |file|
            file.each_line do |line|
              fields = line.split
              next if fields.size < 10

              id, parent_id, _, root = fields
              next unless safe_integer?(id) && safe_integer?(parent_id)
              next unless root.include?('kube')

              matches = UID_REGEX.match(root)
              pod_uid = matches[0] if matches
              break if pod_uid
            end
          end
        rescue StandardError => e
          SolarWindsAPM.logger.debug { "can't read pod uid #{e.message}" }
        end
      else
        SolarWindsAPM.logger.debug { "read pod uid from env #{pod_uid}" }
      end

      resource_attributes = {
        ::OpenTelemetry::SemanticConventions::Resource::K8S_NAMESPACE_NAME => pod_namespace,
        ::OpenTelemetry::SemanticConventions::Resource::K8S_POD_NAME => pod_name,
        ::OpenTelemetry::SemanticConventions::Resource::K8S_POD_UID => pod_uid
      }

      resource_attributes.compact!
      SolarWindsAPM.logger.debug { "#{self.class}/#{__method__}] retrieved resource_attributes: #{resource_attributes.inspect}." }
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
      SolarWindsAPM.logger.info { "#{gem_name} is loaded." }
    rescue LoadError => e
      SolarWindsAPM.logger.debug { "No #{gem_name} found. #{e.message}" }
    end

    def self.safe_integer?(number)
      min_safe_integer = -((2**53) - 1)
      max_safe_integer = (2**53) - 1
      number.is_a?(Integer) && number >= min_safe_integer && number <= max_safe_integer
    end

    def self.windows?
      %w[mingw32 cygwin].any? { |platform| RUBY_PLATFORM.include?(platform) }
    end

    def self.random_uuid
      SecureRandom.uuid
    end
  end
end
