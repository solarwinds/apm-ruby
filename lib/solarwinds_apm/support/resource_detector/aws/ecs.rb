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
    module ECS
      module_function

      CONTAINER_ID_LENGTH = 64
      DEFAULT_CGROUP_PATH = '/proc/self/cgroup'
      HTTP_TIMEOUT = 1

      def detect
        ecs_instance = ENV['ECS_CONTAINER_METADATA_URI_V4'] || ENV.fetch('ECS_CONTAINER_METADATA_URI', nil)
        unless ecs_instance
          SolarWindsAPM.logger.debug { 'AwsEcsDetector: Process is not on ECS' }
          return ::OpenTelemetry::SDK::Resources::Resource.create({})
        end

        gather_data
      end

      # curl http://169.254.169.254/latest/meta-data/hostname
      def gather_data
        attribute = {
          ::OpenTelemetry::SemanticConventions::Resource::CLOUD_PROVIDER => 'aws',
          ::OpenTelemetry::SemanticConventions::Resource::CLOUD_PLATFORM => 'aws_ecs',
          ::OpenTelemetry::SemanticConventions::Resource::CONTAINER_ID => resolve_container_id,
          ::OpenTelemetry::SemanticConventions::Resource::HOST_NAME => Socket.gethostname
        }

        metadata_url = ENV.fetch('ECS_CONTAINER_METADATA_URI_V4', nil)
        if metadata_url
          container_metadata = get_url_as_json(metadata_url)
          task_metadata = get_url_as_json("#{metadata_url}/task")

          merge_metadata(attribute, container_metadata, task_metadata)
        end

        attribute.compact!
        ::OpenTelemetry::SDK::Resources::Resource.create(attribute)
      end

      def resolve_container_id
        container_id = nil
        begin
          raw_data = File.read(DEFAULT_CGROUP_PATH).strip
          raw_data.each_line do |line|
            if line.length > CONTAINER_ID_LENGTH
              container_id = line[-CONTAINER_ID_LENGTH..]
              break
            end
          end
        rescue StandardError => e
          SolarWindsAPM.logger.debug { "AwsEcsDetector failed to read container ID: #{e.message}" }
        end
        container_id
      end

      def make_request(uri, request)
        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = HTTP_TIMEOUT
        http.read_timeout = HTTP_TIMEOUT

        begin
          ::OpenTelemetry::Common::Utilities.untraced do
            http.request(request)
          end
        rescue StandardError => e
          OpenTelemetry.logger.debug { "ECS metadata service request failed: #{e.message}" }
          nil
        end
      end

      def merge_metadata(attribute, container_metadata, task_metadata)
        if task_metadata
          task_arn = task_metadata['TaskARN']
          base_arn = task_arn[0, task_arn.rindex(':')]
          cluster = task_metadata['Cluster']
          account_id = get_account_id_from_arn(task_arn)
          region = get_region_from_arn(task_arn)

          attribute[::OpenTelemetry::SemanticConventions::Resource::AWS_ECS_CLUSTER_ARN] = cluster.start_with?('arn:') ? cluster : "#{base_arn}:cluster/#{cluster}"
          attribute[::OpenTelemetry::SemanticConventions::Resource::AWS_ECS_LAUNCHTYPE] = task_metadata['LaunchType']
          attribute[::OpenTelemetry::SemanticConventions::Resource::AWS_ECS_TASK_ARN] = task_arn
          attribute[::OpenTelemetry::SemanticConventions::Resource::AWS_ECS_TASK_FAMILY] = task_metadata['Family']
          attribute[::OpenTelemetry::SemanticConventions::Resource::AWS_ECS_TASK_REVISION] = task_metadata['Revision']

          attribute[::OpenTelemetry::SemanticConventions::Resource::CLOUD_ACCOUNT_ID] = account_id
          attribute[::OpenTelemetry::SemanticConventions::Resource::CLOUD_REGION] = region

          attribute[::OpenTelemetry::SemanticConventions::Resource::CLOUD_AVAILABILITY_ZONE] = task_metadata['AvailabilityZone']
        else
          SolarWindsAPM.logger.debug { 'Missing task_metadata from ECS resource detection' }
        end

        if container_metadata
          container_arn = container_metadata['ContainerARN']
          attribute['cloud.resource_id'] = container_arn
          attribute[::OpenTelemetry::SemanticConventions::Resource::AWS_ECS_CONTAINER_ARN] = container_metadata['ContainerARN']

          if container_metadata['LogDriver'] == 'awslogs' || container_metadata['LogOptions']
            log_options = container_metadata['LogOptions']
            log_region = log_options['awslogs-region'] || get_region_from_arn(container_arn)
            aws_account_id = get_account_id_from_arn(container_arn)
            logs_group_name = log_options['awslogs-region']
            logs_group_arn = "arn:aws:logs:#{log_region}:#{aws_account_id}:log-group:#{logs_group_name}"
            logs_stream_name = log_options['awslogs-stream']
            logs_stream_arn = "arn:aws:logs:#{log_region}:#{aws_account_id}:log-group:#{logs_group_name}:log-stream:#{logs_stream_name}"

            attribute[::OpenTelemetry::SemanticConventions::Resource::AWS_LOG_GROUP_NAMES] = [logs_group_name]
            attribute[::OpenTelemetry::SemanticConventions::Resource::AWS_LOG_GROUP_ARNS] = [logs_group_arn]
            attribute[::OpenTelemetry::SemanticConventions::Resource::AWS_LOG_STREAM_NAMES] = [logs_stream_name]
            attribute[::OpenTelemetry::SemanticConventions::Resource::AWS_LOG_STREAM_ARNS] = [logs_stream_arn]
          else
            SolarWindsAPM.logger.debug { 'Missing log option data in container_metadata from ECS resource detection' }
          end
        else
          SolarWindsAPM.logger.debug { 'Missing container_metadata from ECS resource detection' }
        end

        attribute.compact!
      end

      def get_account_id_from_arn(task_arn)
        matches = task_arn.to_s.match(/arn:aws:ecs:[^:]+:([^:]+):.*/)
        matches ? matches[1] : nil
      end

      def get_region_from_arn(task_arn)
        matches = task_arn.to_s.match(/arn:aws:ecs:([^:]+):.*/)
        matches ? matches[1] : nil
      end

      def get_url_as_json(url)
        uri = URI.parse(url)
        request = Net::HTTP::Get.new(uri)
        response = make_request(uri, request)

        return nil unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)
      end
    end
  end
end
