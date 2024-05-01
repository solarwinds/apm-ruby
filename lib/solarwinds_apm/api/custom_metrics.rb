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
      def increment_metric(name, count = 1, with_hostname = false, tags_kvs = {}) # rubocop:disable Style/OptionalBooleanParameter
        return true unless SolarWindsAPM.loaded

        with_hostname = with_hostname ? 1 : 0
        tags, tags_count = make_tags(tags_kvs)
        SolarWindsAPM::CustomMetrics.increment(name.to_s, count, with_hostname, nil, tags, tags_count).zero?
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
      def summary_metric(name, value, count = 1, with_hostname = false, tags_kvs = {}) # rubocop:disable Style/OptionalBooleanParameter
        return true unless SolarWindsAPM.loaded

        with_hostname = with_hostname ? 1 : 0
        tags, tags_count = make_tags(tags_kvs)
        SolarWindsAPM::CustomMetrics.summary(name.to_s, value, count, with_hostname, nil, tags, tags_count).zero?
      end

      private

      def make_tags(tags_kvs)
        unless tags_kvs.is_a?(Hash)
          SolarWindsAPM.logger.warn("[solarwinds_apm/metrics] CustomMetrics received tags_kvs that are not a Hash (found #{tags_kvs.class}), setting tags_kvs = {}")
          tags_kvs = {}
        end
        count = tags_kvs.size
        tags = SolarWindsAPM::MetricTags.new(count)

        tags_kvs.each_with_index do |(k, v), i|
          tags.add(i, k.to_s, v.to_s)
        end

        [tags, count]
      end
    end
  end
end
