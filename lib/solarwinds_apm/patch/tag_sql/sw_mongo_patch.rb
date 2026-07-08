# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  module Patch
    module TagSql
      module SWOMongoPatch
        def execute_with_span(span, operation)
          traceparent = ::SolarWindsAPM::Patch::TagSql::SWODboUtils.annotated_traceparent
          original = operation.spec[:comment].to_s
          operation.spec[:comment] = original.empty? ? traceparent : "#{original}; #{traceparent}"
          super
        end
      end

      module SWOMongoPatchV2220
        # from server/connection_base.rb in mongo 2.22.0
        def deliver(message, context, options = {})
          if message.is_a?(Mongo::Protocol::Msg)
            main_doc = message.instance_variable_get(:@main_document)
            if main_doc
              traceparent = ::SolarWindsAPM::Patch::TagSql::SWODboUtils.annotated_traceparent
              original = main_doc['comment'].to_s
              main_doc['comment'] = original.empty? ? traceparent : "#{original}; #{traceparent}"
            end
          end
          super
        end
      end
    end
  end
end

if defined?(Mongo::Tracing::OpenTelemetry::OperationTracer) && Gem::Version.new(Mongo::VERSION) >= Gem::Version.new('2.23.0')
  Mongo::Tracing::OpenTelemetry::OperationTracer.prepend(SolarWindsAPM::Patch::TagSql::SWOMongoPatch)
elsif defined?(OpenTelemetry::Instrumentation::Mongo::CommandSerializer) && Gem::Version.new(Mongo::VERSION) < Gem::Version.new('2.23.0')
  Mongo::Server::ConnectionBase.prepend(SolarWindsAPM::Patch::TagSql::SWOMongoPatchV2220)
end
