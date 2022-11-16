module SolarWindsOTelAPM
  module OpenTelemetry
  
    class Transformer

      DECISION = "{}"
      SPAN_ID_HEX = "{:016x}"
      TRACE_FLAGS_HEX = "{:02x}"
      TRACE_ID_HEX = "{:032x}"
      VERSION = "00"


      def self.sw_from_context(span_context)
        flag = span_context.trace_flags.sampled?? 1 : 0
        sw = "#{span_context.hex_span_id}-0#{flag}"
        sw
      end

      def self.trace_state_header(trace_state)
        arr = Array.new
        trace_state.to_h.each do |key, value|
          arr << "#{key}=#{value}"
        end
        arr.join(",")
      end

      # Generates a liboboe W3C compatible trace_context from provided OTel span context.
      def self.traceparent_from_context span_context
        flag = span_context.trace_flags.sampled?? 1 : 0
        xtr = "#{version}-#{span_data.hex_trace_id}-#{span_data.hex_span_id}-0#{flag}"
        logger.debug("Generated traceparent {} from {}".format(xtr, span_context))
        xtr
      end

      # Formats tracestate sw value from span_id and liboboe decision as 16-byte span_id with 8-bit trace_flags
      # e.g. 1a2b3c4d5e6f7g8h-01
      def self.sw_from_span_and_decision span_id, decision
        "-".join([span_id, decision])
      end

      # Formats trace flags as 8-bit field
      # or use trace_flags.unpack1('H*')
      def self.trace_flags_from_int trace_flags
        flag = trace_flags.sampled?? 1 : 0
        "0#{flag}"
      end

      def self.is_sampled? decision
        return (decision == ::OpenTelemetry::SDK::Trace::Samplers::Decision::RECORD_AND_SAMPLE)
      end

      def self.span_id_from_sw sw_value

      end
      
    end

  end
  
end