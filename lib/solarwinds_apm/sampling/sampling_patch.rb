
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

OpenTelemetry::Exporter::OTLP::Metrics::MetricsExporter.prepend(SolarWindsAPM::MetricsExporter::Patch)
