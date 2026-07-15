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
        # Annotate the final OP_MSG document rather than the operation spec.
        #
        # ConnectionBase#deliver is the shared boundary immediately before
        # serialization, so this works independently of the driver's
        # OpenTelemetry implementation and its internal tracer classes.
        def deliver(message, context, options = {})
          annotate_message_comment(message)
          super
        end
        private :deliver

        private

        def annotate_message_comment(message)
          return unless defined?(::Mongo::Protocol::Msg) &&
                        message.is_a?(::Mongo::Protocol::Msg)

          main_document = message.instance_variable_get(:@main_document)
          return unless main_document

          traceparent = ::SolarWindsAPM::Patch::TagSql::SWODboUtils.annotated_traceparent
          return if traceparent.nil? || traceparent.empty?

          key = comment_key(main_document)
          main_document[key] = annotated_comment(main_document[key], traceparent)
        end

        def comment_key(main_document)
          return 'comment' if main_document.key?('comment')
          return :comment if main_document.key?(:comment)

          'comment'
        end

        def annotated_comment(original, traceparent)
          case original
          when nil
            traceparent
          when String
            original.empty? ? traceparent : "#{original}; #{traceparent}"
          when Hash, BSON::Document
            # Real document: add traceparent as a sibling key.
            # Guard against clobbering a user key of the same name.
            doc = BSON::Document.new(original)
            if doc.key?('traceparent') || doc.key?(:traceparent)
              doc['swo_traceparent'] = traceparent
            else
              doc['traceparent'] = traceparent
            end
            doc
          else
            # Scalar BSON value (ObjectId, Time, Integer, Float, true/false, ...).
            # These have no fields to extend, so wrap them in a new document.
            BSON::Document.new(
              'swo_original_comment' => original,
              'traceparent' => traceparent
            )
          end
        end
      end
    end
  end
end

# ConnectionBase#deliver exists before 2.22.0 and remains the common
# serialization path in 2.23.0 and newer. Do not couple this patch to
# either of the driver's OpenTelemetry integration implementations.
if defined?(::Mongo::Server::ConnectionBase)
  ::Mongo::Server::ConnectionBase.prepend(
    ::SolarWindsAPM::Patch::TagSql::SWOMongoPatch
  )
end

# Why use execute_with_span or not execute_with_span?
#
# execute_with_span only runs when the driver's OpenTelemetry tracing is enabled.
# Look at the real entry point, Tracer#trace_operation in tracer.rb:72-76:
# And enabled? is driven by OTEL_RUBY_INSTRUMENTATION_MONGODB_ENABLED (tracer.rb:42-46).
# So if that env var isn't set to true/1/yes, OperationTracer#trace_operation is never called,
# and therefore your prepended execute_with_span never fires — your traceparent silently disappears.
