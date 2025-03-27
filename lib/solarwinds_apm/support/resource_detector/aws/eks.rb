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

module SolarWindsAPM
  module ResourceDetector
    module EKS
      module_function

      K8S_SVC_URL = 'kubernetes.default.svc'
      K8S_TOKEN_PATH = '/var/run/secrets/kubernetes.io/serviceaccount/token'
      K8S_CERT_PATH = '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt'
      AUTH_CONFIGMAP_PATH = '/api/v1/namespaces/kube-system/configmaps/aws-auth'
      CW_CONFIGMAP_PATH = '/api/v1/namespaces/amazon-cloudwatch/configmaps/cluster-info'
      CONTAINER_ID_LENGTH = 64
      DEFAULT_CGROUP_PATH = '/proc/self/cgroup'
      TIMEOUT_MS = 2000
      UTF8_UNICODE = 'utf-8'

      def detect
        ::OpenTelemetry::SDK::Resources::Resource.create(gather_data)
      end

      def gather_data
        raise StandardError unless File.exist?(K8S_TOKEN_PATH) && File.readable?(K8S_TOKEN_PATH)

        k8scert = File.read(K8S_CERT_PATH) if File.exist?(K8S_CERT_PATH) && File.readable?(K8S_CERT_PATH)

        raise StandardError unless eks?(k8scert)

        container_id = resolve_container_id
        cluster_name = get_cluster_name(k8scert)

        if container_id.nil? && cluster_name.nil?
          {}
        else
          {
            ::OpenTelemetry::SemanticConventions::Resource::CLOUD_PROVIDER => 'aws',
            ::OpenTelemetry::SemanticConventions::Resource::CLOUD_PLATFORM => 'aws_eks',
            ::OpenTelemetry::SemanticConventions::Resource::K8S_CLUSTER_NAME => cluster_name || nil,
            ::OpenTelemetry::SemanticConventions::Resource::CONTAINER_ID => container_id || nil
          }
        end
      rescue StandardError => e
        SolarWindsAPM.logger.warn "Gather data for AWS EKS resource detector failed: #{e.message}"
        {}
      end

      def resolve_container_id
        container_id = nil
        begin
          raw_data = File.read(DEFAULT_CGROUP_PATH, encoding: UTF8_UNICODE).strip
          raw_data.each_line do |line|
            if line.length > CONTAINER_ID_LENGTH
              container_id = line[-CONTAINER_ID_LENGTH..]
              break
            end
          end
        rescue StandardError => e
          SolarWindsAPM.logger.debug "AwsEksDetector failed to read container ID: #{e.message}"
        end
        container_id
      end

      def get_cluster_name(cert)
        options = {
          ca_file: cert,
          headers: {
            'Authorization' => k8s_cred_header
          },
          host: K8S_SVC_URL,
          method: 'GET',
          path: CW_CONFIGMAP_PATH,
          timeout: TIMEOUT_MS / 1000
        }

        cluster_name = nil
        response = fetch_string(options)
        begin
          cluster_name = JSON.parse(response).dig('data', 'cluster.name')
        rescue StandardError => e
          SolarWindsAPM.logger.debug "Cannot get cluster name on EKS: #{e.message}"
        end

        cluster_name
      end

      def eks?(cert)
        options = {
          ca_cert: cert,
          headers: {
            'Authorization' => k8s_cred_header
          },
          hostname: K8S_SVC_URL,
          method: 'GET',
          path: AUTH_CONFIGMAP_PATH,
          timeout: TIMEOUT_MS / 1000
        }

        !!fetch_string(options)
      end

      def k8s_cred_header
        content = File.read(K8S_TOKEN_PATH).strip
        "Bearer #{content}"
      rescue StandardError => e
        SolarWindsAPM.logger.warn "Unable to read Kubernetes client token: #{e.message}"
        ''
      end

      def fetch_string(options)
        uri = URI::HTTPS.build(host: options[:hostname], path: options[:path])
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.ca_file = options[:ca_cert]
        http.open_timeout = options[:timeout]
        http.read_timeout = options[:timeout]

        request = Net::HTTP::Get.new(uri)
        options[:headers]&.each { |key, value| request[key] = value }

        response = nil
        begin
          ::OpenTelemetry::Common::Utilities.untraced do
            response = http.request(request)
          end
        rescue StandardError => e
          raise "EKS metadata API request error: #{e.message}."
        end

        raise "Failed to load page, status code: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        response.body
      rescue StandardError => e
        SolarWindsAPM.logger.warn "Request failed: #{e.message}"
        nil
      end
    end
  end
end
