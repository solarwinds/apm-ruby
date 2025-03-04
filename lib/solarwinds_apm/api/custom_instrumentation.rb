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
        # Helper method to instrument custom method
        #
        # `add_tracer` can add a custom span to the specified instance or class method that is already defined.
        # It requires the custom span name and optionally takes the span kind and additional attributes
        # in hash format.
        #
        # === Argument:
        #
        # * +method_name+ - (String) A non-empty string that match the method name that need to be instrumented
        # * +span_name+ - (String, optional, default = method_name) A non-empty string that define the span name (default to method_name)
        # * +options+ - (Hash, optional, default = {}) A hash with desired options include attributes and span kind e.g. {attributes: {}, kind: :consumer}
        #
        # === Example:
        #
        #   class DogfoodsController < ApplicationController
        #     include SolarWindsAPM::API::Tracer
        #
        #     def create
        #       @dogfood = Dogfood.new(params.permit(:brand, :name))
        #       @dogfood.save
        #       custom_method
        #     end
        #
        #     def custom_method
        #     end
        #     add_tracer :custom_method, 'custom_name', { attributes: { 'foo' => 'bar' }, kind: :consumer }
        #
        #   end
        #
        #   class DogfoodsController < ApplicationController
        #     def create
        #       @dogfood = Dogfood.new(params.permit(:brand, :name))
        #       @dogfood.save
        #       custom_method
        #     end
        #
        #     def self.custom_method
        #     end
        #
        #     class << self
        #       include SolarWindsAPM::API::Tracer
        #       add_tracer :custom_method, 'custom_name', { attributes: { 'foo' => 'bar' }, kind: :consumer }
        #     end
        #
        #   end
        #
        # === Returns:
        # * nil
        #
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
