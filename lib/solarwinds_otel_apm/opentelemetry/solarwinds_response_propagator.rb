module SolarWindsOTelAPM
  module OpenTelemetry
    module SolarWindsResponsePropagator
      class TextMapPropagator

        HTTP_HEADER_ACCESS_CONTROL_EXPOSE_HEADERS = "Access-Control-Expose-Headers"
        XTRACE_HEADER_NAME = "x-trace"
        XTRACEOPTIONS_RESPONSE_HEADER_NAME = "x-trace-options-response"
        INTL_SWO_EQUALS = "="

        private_constant \
          :HTTP_HEADER_ACCESS_CONTROL_EXPOSE_HEADERS, :XTRACE_HEADER_NAME, 
          :XTRACEOPTIONS_RESPONSE_HEADER_NAME

        # Inject trace context into the supplied carrier.
        #
        # @param [Carrier] carrier The mutable carrier to inject trace context into
        # @param [Context] context The context to read trace context from
        # @param [optional Setter] setter If the optional setter is provided, it
        #   will be used to write context into the carrier, otherwise the default
        #   text map setter will be used.
        def inject(carrier, context: ::OpenTelemetry::Context.current, setter: ::OpenTelemetry::Context::Propagation.text_map_setter)

          SolarWindsOTelAPM.logger.debug "####### SolarWindsResponsePropagator"
          span_context = ::OpenTelemetry::Trace.current_span(context).context
          return unless span_context.valid?
          
          x_trace = Transformer.traceparent_from_context(span_context)
          setter.set(carrier, XTRACE_HEADER_NAME, x_trace)
          exposed_headers = [XTRACE_HEADER_NAME]

          xtraceoptions_response = recover_response_from_tracestate(span_context.tracestate)

          if xtraceoptions_response
            exposed_headers << XTRACEOPTIONS_RESPONSE_HEADER_NAME
            setter.set(carrier, XTRACEOPTIONS_RESPONSE_HEADER_NAME, xtraceoptions_response)
          end

          setter.set(carrier, HTTP_HEADER_ACCESS_CONTROL_EXPOSE_HEADERS, exposed_headers.join(","))

        end

        # Returns the predefined propagation fields. If your carrier is reused, you
        # should delete the fields returned by this method before calling +inject+.
        #
        # @return [Array<String>] a list of fields that will be used by this propagator.
        def fields
          TRACESTATE_HEADER_NAME
        end


        private

        def recover_response_from_tracestate tracestate
          sanitized = tracestate.value(XTraceOptions.get_sw_xtraceoptions_response_key)
          sanitized = "" if sanitized.nil?
          sanitized = sanitized.gsub(SolarWindsOTelAPM::Constants::INTL_SWO_EQUALS_W3C_SANITIZED, SolarWindsOTelAPM::Constants::INTL_SWO_EQUALS)
          sanitized = sanitized.gsub(SolarWindsOTelAPM::Constants::INTL_SWO_COMMA_W3C_SANITIZED, SolarWindsOTelAPM::Constants::INTL_SWO_COMMA)
          sanitized
        end
      end
    end
  end
end
