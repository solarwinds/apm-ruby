#--
# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.
#++

module SolarWindsOTelAPM
  module API
    ##
    # Provides methods related to layer initialization and reporting
    module LayerInit #:nodoc:
      # Internal: Report that instrumentation for the given layer has been
      # installed, as well as the version of instrumentation and version of
      # layer.
      #
      def report_init(layer = :rack) #:nodoc:
        # Don't send __Init in test or if SolarWindsOTelAPM
        # isn't fully loaded (e.g. missing c-extension)
        return if ENV.key?('SW_APM_GEM_TEST') || !SolarWindsOTelAPM.loaded
        platform_info = SolarWindsOTelAPM::Util.build_swo_init_report
        log_init(layer, platform_info)
      end

      ##
      # :nodoc:
      # Deprecated:
      # force_trace has been deprecated and will be removed in a subsequent version.
      #
      def force_trace
        SolarWindsOTelAPM.logger.warn '[solarwinds_apm/api] SolarWindsOTelAPM::API::LayerInit.force_trace has been deprecated and will be ' \
                         'removed in a subsequent version.'

        saved_mode = SolarWindsOTelAPM::Config[:tracing_mode]
        SolarWindsOTelAPM::Config[:tracing_mode] = :enabled
        yield
      ensure
        SolarWindsOTelAPM::Config[:tracing_mode] = saved_mode
      end
    end
  end
end
