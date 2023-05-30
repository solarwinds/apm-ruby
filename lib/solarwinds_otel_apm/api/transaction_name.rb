module SolarWindsOTelAPM
  module API
    ##
    # General utility methods for the gem
    module TransactionName #:nodoc:
      def set_transaction_name(custom_name: '')
        
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
  end
end
