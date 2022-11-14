module OpenTelemetry
  module SDK
    class Configurator

      private

      # override the wrapped_exporters_from_env function to only use solarwinds exporter
      # TODO: need to find way to allow multiple exporter injected
      def wrapped_exporters_from_env
        sw_exporter = Trace::Export::BatchSpanProcessor.new(Kernel.const_get("SolarWindsOTelAPM::OpenTelemetry::SolarWindsExporter").new)
        return [sw_exporter]
      end

      def configure_propagation
        propagators = Kernel.const_get("SolarWindsOTelAPM::OpenTelemetry").solarwinds_propogator
        OpenTelemetry.propagation = Context::Propagation::CompositeTextMapPropagator.compose_propagators([propagators])
      end
    end

  end

end