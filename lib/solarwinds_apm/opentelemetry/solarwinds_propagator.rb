# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  module OpenTelemetry
    module SolarWindsPropagator
      # TextMapPropagator
      # propagator error will be rescued by OpenTelemetry::Context::Propagation::TextMapPropagator
      class TextMapPropagator
        TRACESTATE_HEADER_NAME    = 'tracestate'
        XTRACEOPTIONS_HEADER_NAME = 'x-trace-options'
        XTRACEOPTIONS_SIGNATURE_HEADER_NAME = 'x-trace-options-signature'
        INTL_SWO_X_OPTIONS_KEY    = 'sw_xtraceoptions'
        INTL_SWO_SIGNATURE_KEY    = 'sw_signature'

        private_constant \
          :TRACESTATE_HEADER_NAME, :XTRACEOPTIONS_HEADER_NAME,
          :XTRACEOPTIONS_SIGNATURE_HEADER_NAME, :INTL_SWO_X_OPTIONS_KEY, :INTL_SWO_SIGNATURE_KEY

        # Extract trace context from the supplied carrier.
        #
        # @param [Carrier] carrier The carrier to get the header from
        # @param [optional Context] context Context to be updated with the trace context
        #   extracted from the carrier. Defaults to +Context.current+.
        # @param [optional Getter] getter If the optional getter is provided, it
        #   will be used to read the header from the carrier, otherwise the default
        #   text map getter will be used.
        #
        # @return [Context] context updated with extracted baggage, or the original context
        #   if extraction fails
        def extract(carrier, context: ::OpenTelemetry::Context.current,
                    getter: ::OpenTelemetry::Context::Propagation.text_map_getter)
          SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] extract context: #{context.inspect}" }

          context = ::OpenTelemetry::Context.new({}) if context.nil?
          context = inject_extracted_header(carrier, context, getter, XTRACEOPTIONS_HEADER_NAME, INTL_SWO_X_OPTIONS_KEY)
          inject_extracted_header(carrier, context, getter, XTRACEOPTIONS_SIGNATURE_HEADER_NAME, INTL_SWO_SIGNATURE_KEY)
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
          SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] inject context: #{context.inspect}" }

          span_context = ::OpenTelemetry::Trace.current_span(context)&.context
          SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] span_context: #{span_context.inspect}" }
          return unless span_context&.valid?

          trace_flag = span_context.trace_flags.sampled? ? 1 : 0
          sw_value   = "#{span_context.hex_span_id}-0#{trace_flag}"
          trace_state_header = carrier[TRACESTATE_HEADER_NAME].nil? ? nil : carrier[TRACESTATE_HEADER_NAME]
          SolarWindsAPM.logger.debug do
            "[#{self.class}/#{__method__}] sw_value: #{sw_value}; trace_state_header: #{trace_state_header}"
          end

          # prepare carrier with carrier's or new tracestate
          if trace_state_header.nil?
            # only create new trace state if valid span_id
            unless span_context.span_id == ::OpenTelemetry::Trace::INVALID_SPAN_ID
              trace_state = ::OpenTelemetry::Trace::Tracestate.create({ SolarWindsAPM::Constants::INTL_SWO_TRACESTATE_KEY => sw_value })
              SolarWindsAPM.logger.debug do
                "[#{self.class}/#{__method__}] creating new trace state: #{trace_state.inspect}"
              end
              setter.set(carrier, TRACESTATE_HEADER_NAME, Utils.trace_state_header(trace_state))
            end
          else
            trace_state_from_string = ::OpenTelemetry::Trace::Tracestate.from_string(trace_state_header)
            trace_state = trace_state_from_string.set_value(SolarWindsAPM::Constants::INTL_SWO_TRACESTATE_KEY, sw_value)
            SolarWindsAPM.logger.debug do
              "[#{self.class}/#{__method__}] updating/adding trace state for injection #{trace_state.inspect}"
            end
            setter.set(carrier, TRACESTATE_HEADER_NAME, Utils.trace_state_header(trace_state))
          end
        end

        # Returns the predefined propagation fields. If your carrier is reused, you
        # should delete the fields returned by this method before calling +inject+.
        #
        # @return [Array<String>] a list of fields that will be used by this propagator.
        def fields
          TRACESTATE_HEADER_NAME
        end

        private

        def inject_extracted_header(carrier, context, getter, header, inject_key)
          extracted_header = getter.get(carrier, header)
          context = context.set_value(inject_key, extracted_header) if extracted_header
          SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] #{header}: #{inject_key} = #{extracted_header}" }
          context
        end
      end
    end
  end
end
