module SolarWindsAPM
  # Utils
  class Utils
    VERSION = '00'.freeze

    def self.trace_state_header(trace_state)
      return nil if trace_state.nil?

      arr    = []
      trace_state.to_h.each { |key, value| arr << "#{key}=#{value}" }
      header = arr.join(",")
      SolarWindsAPM.logger.debug {"[#{name}/#{__method__}] generated trace_state_header: #{header}"}
      header
    end

    # Generates a liboboe W3C compatible trace_context from provided OTel span context.
    def self.traceparent_from_context(span_context)
      flag = span_context.trace_flags.sampled?? 1 : 0
      xtr = "#{VERSION}-#{span_context.hex_trace_id}-#{span_context.hex_span_id}-0#{flag}"
      SolarWindsAPM.logger.debug {"[#{name}/#{__method__}] generated traceparent: #{xtr} from #{span_context.inspect}"}
      xtr
    end
  end
end