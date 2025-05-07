# frozen_string_literal: true

module SolarWindsAPM
  module MetricsExporter
    module Patch
      # do not send metrics if no data_points present
      def export(metrics, timeout: nil)
        metrics.reject! { |m| m.data_points.empty? }
        return ::OpenTelemetry::SDK::Metrics::Export::SUCCESS unless metrics.any? { |m| m.data_points.any? }

        super
      end
    end
  end
end

OpenTelemetry::Exporter::OTLP::Metrics::MetricsExporter.prepend(SolarWindsAPM::MetricsExporter::Patch)

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

OpenTelemetry::SDK::Trace::Span.prepend(SolarWindsAPM::Span::Patch)

module SolarWindsAPM
  module MetricsSDK
    module MetricStream
      module Patch
        def initialize(
          name,
          description,
          unit,
          instrument_kind,
          meter_provider,
          instrumentation_scope,
          aggregation
        )
          @pid = nil

          super
        end

        def update(value, attributes)
          reset_on_fork
          super
        end

        def reset_on_fork
          pid = Process.pid
          return if @pid == pid

          @pid = pid

          @meter_provider.metric_readers.each do |reader|
            reader.send(:start) if reader.instance_of?(::OpenTelemetry::SDK::Metrics::Export::PeriodicMetricReader) && !reader.alive?
          end
        end
      end
    end
  end
end

OpenTelemetry::SDK::Metrics::State::MetricStream.prepend(SolarWindsAPM::MetricsSDK::MetricStream::Patch)
