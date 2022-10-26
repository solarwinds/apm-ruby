module OpenTelemetry
  module SDK
    class Configurator

      private

      # override the wrapped_exporters_from_env function to only use solarwinds exporter
      def wrapped_exporters_from_env
        sw_exporter = Trace::Export::BatchSpanProcessor.new(Kernel.const_get("SolarWindsOTelAPM::OpenTelemetry::SolarWindsExporter").new)
        return [sw_exporter]
      end

    end

  end

end