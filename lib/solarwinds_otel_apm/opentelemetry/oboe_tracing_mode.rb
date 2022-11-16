module SolarWindsOTelAPM
  module OpenTelemetry
  
    class OboeTracingMode

      OBOE_SETTINGS_UNSET = -1
      OBOE_TRACE_DISABLED = 0
      OBOE_TRACE_ENABLED = 1
      OBOE_TRIGGER_DISABLED = 0
      OBOE_TRIGGER_ENABLED = 1

      def self.get_oboe_trace_mode tracing_mode
        mode = OBOE_SETTINGS_UNSET
        mode = OBOE_TRACE_ENABLED if tracing_mode == 'enabled'
        mode = OBOE_TRACE_DISABLED if tracing_mode == 'disabled'
        mode
      end

      def self.get_oboe_trigger_trace_mode trigger_trace_mode
        mode = OBOE_SETTINGS_UNSET
        mode = OBOE_TRIGGER_ENABLED if trigger_trace_mode == 'enabled'
        mode = OBOE_TRIGGER_DISABLED if trigger_trace_mode == 'disabled'
        mode
      end

    end

  end
  
end