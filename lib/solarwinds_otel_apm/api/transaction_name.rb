module SolarWindsOTelAPM
  module API
    module TransactionName
      # Public: Change the transaction name for the current trace.
      #
      # Examples
      #
      #   SolarWindsOTelAPM::API.set_transaction_name('new_name')
      #   # => true
      #
      #
      # Parameters:
      #   custom_name - The name you want to change the current transaction name (String)
      #
      # Returns:
      #   True or False (Boolean)
      #
      def set_transaction_name(custom_name=nil)
        
        return false if custom_name.nil? || custom_name.empty?

        solarwinds_processor = SolarWindsOTelAPM::OTelConfig.class_variable_get(:@@config)[:span_processor]
        if solarwinds_processor.nil?
          SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/transaction_name] Solarwinds processor is missing. Set transaction name failed."
          return false
        end

        entry_trace_id = ::OpenTelemetry::Baggage.value(::SolarWindsOTelAPM::Constants::INTL_SWO_CURRENT_TRACE_ID)
        entry_span_id  = ::OpenTelemetry::Baggage.value(::SolarWindsOTelAPM::Constants::INTL_SWO_CURRENT_SPAN_ID)

        if entry_trace_id.nil? || entry_span_id.nil? 
          SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/transaction_name] Cannot cache custom transaction name #{custom_name} because OTel service entry span not started; ignoring"
          return false
        end

        trace_span_id = "#{entry_trace_id}-#{entry_span_id}"
        solarwinds_processor.txn_manager.set(trace_span_id,custom_name) 
        SolarWindsOTelAPM.logger.debug "####### Cached custom transaction name for #{trace_span_id} as #{custom_name}"
        true
      end
    end
  end
end
