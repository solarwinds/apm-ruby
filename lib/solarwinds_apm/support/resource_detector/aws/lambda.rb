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
    module Lambda
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
        attribute = gather_data
        ::OpenTelemetry::SDK::Resources::Resource.create(attribute)
      end

      def gather_data
        return {} unless ENV['AWS_EXECUTION_ENV'].to_s.start_with?('AWS_Lambda_')

        region = ENV.fetch('AWS_REGION', nil)
        function_name = ENV.fetch('AWS_LAMBDA_FUNCTION_NAME', nil)
        function_version = ENV.fetch('AWS_LAMBDA_FUNCTION_VERSION', nil)
        memory_size = ENV.fetch('AWS_LAMBDA_FUNCTION_MEMORY_SIZE', nil)

        # These environment variables are not available in Lambda SnapStart functions
        log_group_name = ENV.fetch('AWS_LAMBDA_LOG_GROUP_NAME', nil)
        log_stream_name = ENV.fetch('AWS_LAMBDA_LOG_STREAM_NAME', nil)

        attributes = {
          ::OpenTelemetry::SemanticConventions::Resource::CLOUD_PROVIDER => 'aws',
          ::OpenTelemetry::SemanticConventions::Resource::CLOUD_PLATFORM => 'aws_lambda',
          ::OpenTelemetry::SemanticConventions::Resource::CLOUD_REGION => region,
          ::OpenTelemetry::SemanticConventions::Resource::FAAS_NAME => function_name,
          ::OpenTelemetry::SemanticConventions::Resource::FAAS_VERSION => function_version,
          ::OpenTelemetry::SemanticConventions::Resource::FAAS_MAX_MEMORY => memory_size.to_i * 1024 * 1024
        }

        attributes[::OpenTelemetry::SemanticConventions::Resource::AWS_LOG_GROUP_NAMES] = [log_group_name] if log_group_name
        attributes[::OpenTelemetry::SemanticConventions::Resource::FAAS_INSTANCE] = log_stream_name if log_stream_name
      end
    end
  end
end
