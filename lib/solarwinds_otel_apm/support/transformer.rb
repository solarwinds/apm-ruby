module SolarWindsOTelAPM
  module OpenTelemetry
    # Transformer
    class Transformer
      VERSION = '00'.freeze

      def self.sw_from_context(span_context)
        flag = span_context.trace_flags.sampled?? 1 : 0
        "#{span_context.hex_span_id}-0#{flag}"
      end

      def self.trace_state_header(trace_state)
        arr = []
        trace_state.to_h.each do |key, value|
          arr << "#{key}=#{value}"
        end
        arr.join(",")
      end

      # Generates a liboboe W3C compatible trace_context from provided OTel span context.
      def self.traceparent_from_context(span_context)
        flag = span_context.trace_flags.sampled?? 1 : 0
        xtr = "#{VERSION}-#{span_context.hex_trace_id}-#{span_context.hex_span_id}-0#{flag}"
        SolarWindsOTelAPM.logger.debug("Generated traceparent #{xtr} from #{span_context.inspect}")
        xtr
      end

      # Formats tracestate sw value from span_id and liboboe decision as 16-byte span_id with 8-bit trace_flags
      # e.g. 1a2b3c4d5e6f7g8h-01
      def self.sw_from_span_and_decision(span_id, decision)
        [span_id, decision].join("-")
      end

      # trace_flags [Integer]
      def self.trace_flags_from_int(trace_flags)
        "0#{trace_flags}"
      end

      def self.trace_flags_from_boolean(trace_flags)
        trace_flags == true ? "01" : "00"
      end

      def self.sampled?(decision)
        decision == ::OpenTelemetry::SDK::Trace::Samplers::Decision::RECORD_AND_SAMPLE
      end

      def self.span_id_from_sw(sw_value)
        sw_value.split("-")[0]
      end

      def self.create_key(name_)
        ::OpenTelemetry::Context.create_key(name_)
      end
    end
  end
end