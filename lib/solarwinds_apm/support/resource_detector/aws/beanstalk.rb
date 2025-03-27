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
    # Beanstalk
    module Beanstalk
      module_function

      DEFAULT_BEANSTALK_CONF_PATH = '/var/elasticbeanstalk/xray/environment.conf'
      WIN_OS_BEANSTALK_CONF_PATH = 'C:\\Program Files\\Amazon\\XRay\\environment.conf'

      def detect
        beanstalk_config_path = if RUBY_PLATFORM.include?('mingw32') || RUBY_PLATFORM.include?('mswin')
                                  WIN_OS_BEANSTALK_CONF_PATH
                                else
                                  DEFAULT_BEANSTALK_CONF_PATH
                                end

        attribute = gather_data(beanstalk_config_path)
        ::OpenTelemetry::SDK::Resources::Resource.create(attribute)
      end

      def gather_data(config_path)
        raw_data = File.read(config_path, encoding: 'utf-8')
        parsed_data = JSON.parse(raw_data)
        {
          ::OpenTelemetry::SemanticConventions::Resource::CLOUD_PROVIDER => 'aws',
          ::OpenTelemetry::SemanticConventions::Resource::CLOUD_PLATFORM => 'aws_elastic_beanstalk',
          ::OpenTelemetry::SemanticConventions::Resource::SERVICE_NAME => 'aws_elastic_beanstalk',
          ::OpenTelemetry::SemanticConventions::Resource::SERVICE_NAMESPACE => parsed_data['environment_name'],
          ::OpenTelemetry::SemanticConventions::Resource::SERVICE_VERSION => parsed_data['version_label'],
          ::OpenTelemetry::SemanticConventions::Resource::SERVICE_INSTANCE_ID => parsed_data['deployment_id']
        }
      rescue StandardError => e
        SolarWindsAPM.logger.warn "Gather data for AWS Elastic Beanstalk resource detector failed: #{e.message}"
        {}
      end
    end
  end
end
