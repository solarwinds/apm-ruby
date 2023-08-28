module SolarWindsAPM
  module OpenTelemetry
    module SolarWindsResponsePropagator
      # ResponsePropagator
      class TextMapPropagator
        HTTP_HEADER_ACCESS_CONTROL_EXPOSE_HEADERS = "Access-Control-Expose-Headers".freeze
        XTRACE_HEADER_NAME                        = "x-trace".freeze
        XTRACEOPTIONS_RESPONSE_HEADER_NAME        = "x-trace-options-response".freeze
        INTL_SWO_EQUALS                           = "=".freeze

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
        def inject(carrier, context: ::OpenTelemetry::Context.current, setter: ::OpenTelemetry::Context::Propagation.text_map_setter)

          span_context = ::OpenTelemetry::Trace.current_span(context).context
          SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] context: #{context.inspect}; span_context: #{span_context.inspect}"}
          return unless span_context&.valid?
          
          x_trace                = Transformer.traceparent_from_context(span_context)
          exposed_headers        = [XTRACE_HEADER_NAME]
          xtraceoptions_response = recover_response_from_tracestate(span_context.tracestate)

          SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] x-trace: #{x_trace}; exposed headers: #{exposed_headers.inspect}; x-trace-options-response: #{xtraceoptions_response}"}
          exposed_headers.append(XTRACEOPTIONS_RESPONSE_HEADER_NAME) unless xtraceoptions_response.empty?

          setter.set(carrier, XTRACE_HEADER_NAME, x_trace)
          setter.set(carrier, XTRACEOPTIONS_RESPONSE_HEADER_NAME, xtraceoptions_response) unless xtraceoptions_response.empty?
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

        # sw_xtraceoptions_response_key -> xtrace_options_response
        def recover_response_from_tracestate(tracestate)
          sanitized = tracestate.value(XTraceOptions.sw_xtraceoptions_response_key)
          sanitized = "" if sanitized.nil?
          sanitized = sanitized.gsub(SolarWindsAPM::Constants::INTL_SWO_EQUALS_W3C_SANITIZED, SolarWindsAPM::Constants::INTL_SWO_EQUALS)
          sanitized = sanitized.gsub(SolarWindsAPM::Constants::INTL_SWO_COMMA_W3C_SANITIZED, SolarWindsAPM::Constants::INTL_SWO_COMMA)
          SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] recover_response_from_tracestate sanitized: #{sanitized.inspect}"}
          sanitized
        end
      end
    end
  end
end
