#--
# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.
#++

module SolarWindsOTelAPM
  ##
  # Provides methods related to layer initialization and reporting
  module LayerInit #:nodoc:
    # Internal: Report that instrumentation for the given layer has been
    # installed, as well as the version of instrumentation and version of
    # layer.
    #
    def self.report_init(layer = :rack) #:nodoc:
      # Don't send __Init in test or if SolarWindsOTelAPM
      # isn't fully loaded (e.g. missing c-extension)
      return if ENV.key?('SW_APM_GEM_TEST') || !SolarWindsOTelAPM.loaded
      platform_info = SolarWindsOTelAPM::Util.build_swo_init_report
      log_init(layer, platform_info)
    end

    ##
    #:nodoc:
    # Internal: Reports agent init to the collector
    #
    # ==== Arguments
    #
    # * +layer+ - The layer the reported event belongs to
    # * +kvs+ - A hash containing key/value pairs that will be reported along with this event
    def self.log_init(layer = :rack, kvs = {})
      context = SolarWindsOTelAPM::Metadata.makeRandom
      return SolarWindsOTelAPM::Context.toString unless context.isValid

      event = context.createEvent
      event.addInfo(SW_APM_STR_LAYER, layer.to_s)
      event.addInfo(SW_APM_STR_LABEL, 'single')
      kvs.each do |k, v|
        event.addInfo(k, v.to_s)
      end

      SolarWindsOTelAPM::Reporter.sendStatus(event, context)
      SolarWindsOTelAPM::Context.toString
    end
    
  end
end