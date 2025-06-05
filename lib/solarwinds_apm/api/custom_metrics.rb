# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  module API
    module CustomMetrics
      # Send counts
      #
      # Use this method to report the number of times an action occurs. The metric counts reported are summed and flushed every 60 seconds.
      #
      # === Arguments:
      #
      # * +name+          (String) Name to be used for the metric. Must be 255 or fewer characters and consist only of A-Za-z0-9.:-*
      # * +count+         (Integer, optional, default = 1): Count of actions being reported
      # * +with_hostname+ (Boolean, optional, default = false): Indicates if the host name should be included as a tag for the metric
      # * +tags_kvs+      (Hash, optional): List of key/value pairs to describe the metric. The key must be <= 64 characters, the value must be <= 255 characters, allowed characters: A-Za-z0-9.:-_
      #
      # === Example:
      #
      #   class WorkTracker
      #     def counting(name, tags = {})
      #       yield # yield to where work is done
      #       SolarWindsAPM::API.increment_metric(name, 1, false, tags)
      #     end
      #   end
      #
      # === Returns:
      # * Boolean
      #
      def increment_metric(_name, _count = 1, _with_hostname = false, _tags_kvs = {}) # rubocop:disable Style/OptionalBooleanParameter
        SolarWindsAPM.logger.warn { 'increment_metric have been deprecated. Please use opentelemetry metrics-sdk to log metrics data.' }
        false
      end

      # Send values with counts
      #
      # Use this method to report a value for each or multiple counts. The metric values reported are aggregated and flushed every 60 seconds. The dashboard displays the average value per count.
      #
      # === Arguments:
      #
      # * +name+          (String) Name to be used for the metric. Must be 255 or fewer characters and consist only of A-Za-z0-9.:-*
      # * +value+         (Numeric) Value to be added to the current sum
      # * +count+         (Integer, optional, default = 1): Count of actions being reported
      # * +with_hostname+ (Boolean, optional, default = false): Indicates if the host name should be included as a tag for the metric
      # * +tags_kvs+      (Hash, optional): List of key/value pairs to describe the metric. The key must be <= 64 characters, the value must be <= 255 characters, allowed characters: A-Za-z0-9.:-_
      #
      # === Example:
      #
      #   class WorkTracker
      #     def timing(name, tags = {})
      #       start = Time.now
      #       yield # yield to where work is done
      #       duration = Time.now - start
      #       SolarWindsAPM::API.summary_metric(name, duration, 1, false, tags)
      #     end
      #   end
      #
      # === Returns:
      # * Boolean
      #
      def summary_metric(_name, _value, _count = 1, _with_hostname = false, _tags_kvs = {}) # rubocop:disable Style/OptionalBooleanParameter
        SolarWindsAPM.logger.warn { 'summary_metric have been deprecated. Please use opentelemetry metrics-sdk to log metrics data.' }
        false
      end

      private

      def make_tags(_tags_kvs)
        nil
      end
    end
  end
end
