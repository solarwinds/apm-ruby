# frozen_string_literal: true

# © 2024 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  module API
    module Tracer
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def add_tracer(method_name, span_name = nil, options = {})
          span_name = name.nil? ? "#{to_s.split(':').last&.tr('>', '')}/#{__method__}" : "#{name}/#{__method__}" if span_name.nil?

          original_method = instance_method(method_name)

          define_method(method_name) do |*args, &block|
            SolarWindsAPM::API.in_span(span_name, **options) do |_span|
              original_method.bind_call(self, *args, &block)
            end
          end
        end
      end
    end
  end
end
