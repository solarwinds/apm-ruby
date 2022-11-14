module SolarWindsOTelAPM
  module OpenTelemetry
  
    class Transformer

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

    end

  end
  
end