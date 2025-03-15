
module SolarWindsAPM
  module MetricsExporter
    module Patch
      # do not send metrics if no data_points present
      def export(metrics, timeout: nil)
        return ::OpenTelemetry::SDK::Metrics::Export::SUCCESS unless metrics.any? { |m| m.data_points.any? }
        super(metrics, timeout: timeout)
      end
    end
  end
end

module SolarWindsAPM
  module Span
    module Patch
      def finish(end_timestamp: nil)
        @mutex.synchronize do
          if @ended
            ::OpenTelemetry.logger.warn('Calling finish on an ended Span.')
            return self
          end
        end

        @span_processors.each do |processor|
          processor.on_finishing(self) if processor.respond_to?(:on_finishing)
        end

        @mutex.synchronize do
          @end_timestamp = relative_timestamp(end_timestamp)
          @attributes = validated_attributes(@attributes).freeze
          @events.freeze
          @links.freeze
          @ended = true
        end
        @span_processors.each { |processor| processor.on_finish(self) }
        self
      end
    end
  end
end

OpenTelemetry::Exporter::OTLP::Metrics::MetricsExporter.prepend(SolarWindsAPM::MetricsExporter::Patch)
OpenTelemetry::SDK::Trace::Span.prepend(SolarWindsAPM::Span::Patch)
