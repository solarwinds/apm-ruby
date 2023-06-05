module SolarWindsOTelAPM
  module API
    module TransactionName #:nodoc:
      def set_transaction_name(custom_name=nil)
        
        return false if custom_name.nil? || custom_name.empty?

        ::OpenTelemetry.tracer_provider.instance_variable_get(:@span_processors)&.each do |processor|

          if processor.instance_of?(SolarWindsOTelAPM::OpenTelemetry::SolarWindsProcessor)
            solarwinds_processor = processor

            entry_trace_id = ::OpenTelemetry::Baggage.value(::SolarWindsOTelAPM::Constants::INTL_SWO_CURRENT_TRACE_ID)
            entry_span_id  = ::OpenTelemetry::Baggage.value(::SolarWindsOTelAPM::Constants::INTL_SWO_CURRENT_SPAN_ID)

            if entry_trace_id.nil? || entry_span_id.nil? 
              SolarWindsOTelAPM.logger.warn "####### Cannot cache custom transaction name #{custom_name} because OTel service entry span not started; ignoring"
              return false
            end

            trace_span_id = "#{entry_trace_id}-#{entry_span_id}"
            SolarWindsOTelAPM.logger.debug "####### current trace_span_id is #{trace_span_id}"
            
            solarwinds_processor.txn_manager.set(trace_span_id,custom_name) 
            SolarWindsOTelAPM.logger.debug "####### Cached custom transaction name for #{trace_span_id} as #{custom_name}"

            return true
          end
        end

        SolarWindsOTelAPM.logger.warn "####### Solarwinds processor is missing. Set transaction name failed."
        false
      end
    end
  end
end
