module SolarWindsOTelAPM
  module OpenTelemetry
    module SolarWindsPropagator
      class TextMapPropagator

        TRACESTATE_HEADER_NAME = "tracestate"
        XTRACEOPTIONS_HEADER_NAME = "x-trace-options"
        XTRACEOPTIONS_SIGNATURE_HEADER_NAME = "x-trace-options-signature"
        INTL_SWO_X_OPTIONS_KEY = "sw_xtraceoptions"
        INTL_SWO_SIGNATURE_KEY = "sw_signature"
        INTL_SWO_TRACESTATE_KEY = "sw"

        private_constant \
          :TRACESTATE_HEADER_NAME, :XTRACEOPTIONS_HEADER_NAME, 
          :XTRACEOPTIONS_SIGNATURE_HEADER_NAME, :INTL_SWO_X_OPTIONS_KEY, :INTL_SWO_SIGNATURE_KEY

        # Extract trace context from the supplied carrier.
        # If extraction fails, the original context will be returned
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
        def extract(carrier, context: ::OpenTelemetry::Context.current, getter: ::OpenTelemetry::Context::Propagation.text_map_getter)
          
          context = ::OpenTelemetry::Context.new(Hash.new) if context.nil?

          xtraceoptions_header = getter.get(carrier, XTRACEOPTIONS_HEADER_NAME)
          SolarWindsOTelAPM.logger.debug "####### xtraceoptions_header: #{xtraceoptions_header}"

          return context if xtraceoptions_header.nil?
          
          hash_value = Hash.new
          hash_value[INTL_SWO_X_OPTIONS_KEY] = xtraceoptions_header[0]
          context.update(hash_value)

          signature_header = getter.get(carrier, XTRACEOPTIONS_SIGNATURE_HEADER_NAME)
          SolarWindsOTelAPM.logger.debug "####### signature_header: #{signature_header}"

          hash_value = Hash.new
          hash_value[INTL_SWO_SIGNATURE_KEY] = signature_header[0]
          context.set_values(hash_value) if signature_header
          
          SolarWindsOTelAPM.logger.debug "####### context: #{context}"
          return context

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
          return unless span_context.valid?

          sw_value = Transformer.sw_from_context(span_context)  # sw_value is a string
          trace_state_header = carrier["#{TRACESTATE_HEADER_NAME}"].nil?? nil : carrier["#{TRACESTATE_HEADER_NAME}"]

          # Prepare carrier with carrier's or new tracestate
          trace_state = nil
          if trace_state_header.nil?
            # Only create new trace state if valid span_id
            if span_context.span_id == ::OpenTelemetry::Trace::INVALID_SPAN_ID
              return
            else
              SolarWindsOTelAPM.logger.debug "Creating new trace state for injection with #{sw_value}"
              trace_state_hash = Hash.new
              trace_state_hash[INTL_SWO_TRACESTATE_KEY] = sw_value
              trace_state = ::OpenTelemetry::Trace::Tracestate.create(trace_state_hash)
            end

          else
            trace_state = ::OpenTelemetry::Trace::Tracestate.from_string(trace_state_header)
            # Check if trace_state already contains sw KV
            if trace_state.keys.include? INTL_SWO_TRACESTATE_KEY
              # If so, modify current span_id and trace_flags, and move to beginning of list
              SolarWindsOTelAPM.logger.debug "Updating trace state for injection with #{sw_value}"
              trace_state = trace_state.set_value("#{INTL_SWO_TRACESTATE_KEY}", sw_value)
            else
              # If not, add sw KV to beginning of list
              SolarWindsOTelAPM.logger.debug "Adding KV to trace state for injection with #{sw_value}"
              trace_state = trace_state.set_value("#{INTL_SWO_TRACESTATE_KEY}", sw_value)
            end
          end

          setter.set(carrier, "#{TRACESTATE_HEADER_NAME}", Transformer.trace_state_header(trace_state))

        end

        # Returns the predefined propagation fields. If your carrier is reused, you
        # should delete the fields returned by this method before calling +inject+.
        #
        # @return [Array<String>] a list of fields that will be used by this propagator.
        def fields
          TRACESTATE_HEADER_NAME
        end
      end
    end
  end
end
