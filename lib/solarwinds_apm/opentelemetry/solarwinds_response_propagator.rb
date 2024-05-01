# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  module OpenTelemetry
    module SolarWindsResponsePropagator
      # ResponsePropagator
      # response propagator error will be rescued by OpenTelemetry::Instrumentation::Rack::Middlewares::EventHandler
      class TextMapPropagator
        HTTP_HEADER_ACCESS_CONTROL_EXPOSE_HEADERS = 'Access-Control-Expose-Headers'
        XTRACE_HEADER_NAME                        = 'x-trace'
        XTRACEOPTIONS_RESPONSE_HEADER_NAME        = 'x-trace-options-response'
        INTL_SWO_EQUALS                           = '='

        private_constant \
          :HTTP_HEADER_ACCESS_CONTROL_EXPOSE_HEADERS, :XTRACE_HEADER_NAME,
          :XTRACEOPTIONS_RESPONSE_HEADER_NAME

        def extract(carrier, context: ::OpenTelemetry::Context.current, getter: ::OpenTelemetry::Context::Propagation.text_map_getter) # rubocop:disable Lint/UnusedMethodArgument
          context
        end

        # Inject trace context into the supplied carrier.
        #
        # @param [Carrier] carrier The mutable carrier to inject trace context into
        # @param [Context] context The context to read trace context from
        # @param [optional Setter] setter If the optional setter is provided, it
        #   will be used to write context into the carrier, otherwise the default
        #   text map setter will be used.
        def inject(carrier, context: ::OpenTelemetry::Context.current,
                   setter: ::OpenTelemetry::Context::Propagation.text_map_setter)
          span_context = ::OpenTelemetry::Trace.current_span(context).context
          SolarWindsAPM.logger.debug do
            "[#{self.class}/#{__method__}] context: #{context.inspect}; span_context: #{span_context.inspect}"
          end
          return unless span_context&.valid?

          x_trace                = Utils.traceparent_from_context(span_context)
          exposed_headers        = [XTRACE_HEADER_NAME]
          xtraceoptions_response = recover_response_from_tracestate(span_context.tracestate)

          SolarWindsAPM.logger.debug do
            "[#{self.class}/#{__method__}] x-trace: #{x_trace}; exposed headers: #{exposed_headers.inspect}; x-trace-options-response: #{xtraceoptions_response}"
          end
          exposed_headers.append(XTRACEOPTIONS_RESPONSE_HEADER_NAME) unless xtraceoptions_response.empty?

          setter.set(carrier, XTRACE_HEADER_NAME, x_trace)
          unless xtraceoptions_response.empty?
            setter.set(carrier, XTRACEOPTIONS_RESPONSE_HEADER_NAME,
                       xtraceoptions_response)
          end
          setter.set(carrier, HTTP_HEADER_ACCESS_CONTROL_EXPOSE_HEADERS, exposed_headers.join(','))
        end

        # Returns the predefined propagation fields. If your carrier is reused, you
        # should delete the fields returned by this method before calling +inject+.
        #
        # @return [Array<String>] a list of fields that will be used by this propagator.
        def fields
          TRACESTATE_HEADER_NAME
        end

        private

        # sw_xtraceoptions_response_key -> xtrace_options_response
        def recover_response_from_tracestate(tracestate)
          sanitized = tracestate.value(XTraceOptions.sw_xtraceoptions_response_key)
          sanitized = '' if sanitized.nil?
          sanitized = sanitized.gsub(SolarWindsAPM::Constants::INTL_SWO_EQUALS_W3C_SANITIZED,
                                     SolarWindsAPM::Constants::INTL_SWO_EQUALS)
          sanitized = sanitized.gsub(SolarWindsAPM::Constants::INTL_SWO_COMMA_W3C_SANITIZED,
                                     SolarWindsAPM::Constants::INTL_SWO_COMMA)
          SolarWindsAPM.logger.debug do
            "[#{self.class}/#{__method__}] recover_response_from_tracestate sanitized: #{sanitized.inspect}"
          end
          sanitized
        end
      end
    end
  end
end
