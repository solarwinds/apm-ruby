module SolarWindsOTelAPM
  module OpenTelemetry
    class SolarWindsSampler

      INTERNAL_BUCKET_CAPACITY = "BucketCapacity"
      INTERNAL_BUCKET_RATE = "BucketRate"
      INTERNAL_SAMPLE_RATE = "SampleRate"
      INTERNAL_SAMPLE_SOURCE = "SampleSource"
      INTERNAL_SW_KEYS = "SWKeys"
      LIBOBOE_CONTINUED = -1
      SW_TRACESTATE_CAPTURE_KEY = "sw.w3c.tracestate"
      SW_TRACESTATE_ROOT_KEY = "sw.tracestate_parent_id"
      UNSET = -1
      XTRACEOPTIONS_RESP_AUTH = "auth"
      XTRACEOPTIONS_RESP_IGNORED = "ignored"
      XTRACEOPTIONS_RESP_TRIGGER_IGNORED = "ignored"
      XTRACEOPTIONS_RESP_TRIGGER_NOT_REQUESTED = "not-requested"
      XTRACEOPTIONS_RESP_TRIGGER_TRACE = "trigger-trace"


      attr_reader :description

      def initialize(config={})
        @config = config
        @context = SolarWindsOTelAPM::Context
      end

      def get_description
        "SolarWinds custom opentelemetry sampler"
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

      private

      def calculate_liboboe_decision parent_span_context, xtraceoptions


      end


      def is_decision_continued liboboe_decision

      end


      def otel_decision_from_liboboe liboboe_decision

      end

      def create_xtraceoptions_response_value decision, parent_span_context, xtraceoptions

      end


      def create_new_trace_state decision, parent_span_context, xtraceoptions

      end


      def calculate_trace_state decision, parent_span_context, xtraceoptions

      end

      def remove_response_from_sw trace_state

      end

      def add_tracestate_capture_to_attributes_dict attributes_dict, decision, trace_state, parent_span_context

      end

      def calculate_attributes span_name, attributes, decision, trace_state, parent_span_context, xtraceoptions

      end































    end
  end
end