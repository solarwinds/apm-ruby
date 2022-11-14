module SolarWindsOTelAPM
  module OpenTelemetry
    class SolarWindsSampler

      attr_reader :description

      def initialize(config={})
        @config = config
      end

      def ==(other)
        @decision == other.decision && @description == other.description
      end

      # @api private
      #
      # See {Samplers}.
      def should_sample?(trace_id:, parent_context:, links:, name:, kind:, attributes:)
        ::OpenTelemetry::SDK::Trace::Samplers::Result.new(decision: @decision, tracestate: ::OpenTelemetry::Trace.current_span(parent_context).context.tracestate)
      end

      protected

      attr_reader :decision

    end
  end
end