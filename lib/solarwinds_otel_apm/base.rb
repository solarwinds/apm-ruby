# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

##
# This module is the base module for SolarWindsOTelAPM reporting.
#
module SolarWindsOTelAPMBase
  extend SolarWindsOTelAPM::ThreadLocal

  attr_accessor :reporter
  attr_accessor :loaded

  ##
  # Determines if we are running under a forking webserver
  #
  def forking_webserver?
    if (defined?(::Unicorn) && ($PROGRAM_NAME =~ /unicorn/i)) ||
       (defined?(::Puma) && ($PROGRAM_NAME =~ /puma/i))
      true
    else
      false
    end
  end

  # Change transaction naming
  # Get current processor, and get the txn_manager, then replace the transaction name inside the txn_manager
  def set_transaction_name(custom_name: '')

    # one way to get processor
    # processor = SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:span_processor]

    solarwinds_processor = nil
    processors = ::OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors)

    processors&.each do |processor|
      solarwinds_processor = processor if processor.instance_of?(SolarWindsOTelAPM::OpenTelemetry::SolarWindsProcessor)
    end
    SolarWindsOTelAPM.logger.debug "####### current processor is #{processors.map(&:class)}"

    if solarwinds_processor
      SolarWindsOTelAPM.logger.debug "####### current processor is #{solarwinds_processor.inspect}"
    else
      SolarWindsOTelAPM.logger.warn "####### Solarwinds processor is missing. Set transaction name failed."
      return false
    end

    entry_trace_id = ::OpenTelemetry::Baggage.value(::SolarWindsOTelAPM::Constants::INTL_SWO_CURRENT_TRACE_ID)
    entry_span_id  = ::OpenTelemetry::Baggage.value(::SolarWindsOTelAPM::Constants::INTL_SWO_CURRENT_SPAN_ID)

    if entry_trace_id.nil? || entry_span_id.nil? 
      SolarWindsOTelAPM.logger.warn "####### Cannot cache custom transaction name #{custom_name} because OTel service entry span not started; ignoring"
      return false
    end

    trace_span_id = "#{entry_trace_id}-#{entry_span_id}"
    solarwinds_processor.txn_manager.set(trace_span_id,custom_name) 
    SolarWindsOTelAPM.logger.warn "####### Cached custom transaction name for #{trace_span_id} as #{custom_name}"
    true
  end
end

module SolarWindsOTelAPM
  extend SolarWindsOTelAPMBase
end

# Setup an alias so we don't bug users
# about single letter capitalization
SolarwindsOTelAPM = SolarWindsOTelAPM
SolarWindsOtelApm = SolarWindsOTelAPM
SolarwindsotelApm = SolarWindsOTelAPM
SolarwindsOTELApm = SolarWindsOTelAPM
SolarwindsOTELAPM = SolarWindsOTelAPM
