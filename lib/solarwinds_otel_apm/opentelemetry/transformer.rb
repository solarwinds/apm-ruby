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
        xtr = "#{VERSION}-#{span_context.hex_trace_id}-#{span_context.hex_span_id}-0#{flag}"
        SolarWindsOTelAPM.logger.debug("Generated traceparent #{xtr}, #{span_context}")
        xtr
      end

      # Formats tracestate sw value from span_id and liboboe decision as 16-byte span_id with 8-bit trace_flags
      # e.g. 1a2b3c4d5e6f7g8h-01
      def self.sw_from_span_and_decision span_id, decision
        [span_id, decision].join("-")
      end

      # trace_flags [Integer]
      def self.trace_flags_from_int trace_flags
        "0#{trace_flags}"
      end

      def self.is_sampled? decision
        (decision == ::OpenTelemetry::SDK::Trace::Samplers::Decision::RECORD_AND_SAMPLE)
      end

      def self.span_id_from_sw sw_value
        sw_value.split("-")[0]
      end

      def self.get_current_span context
        span_key = self.create_key('current-span')
        span = context.value(span_key.name)
        return ::OpenTelemetry::Trace::Span::INVALID if span.nil?
        return span
      end

      def self.create_key name_
        ::OpenTelemetry::Context.create_key(name_)
      end

    end

  end
  
end