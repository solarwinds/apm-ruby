module SolarWindsAPM
  module API
    module TransactionName
      # Provide a custom transaction name
      #
      # The SolarWindsAPM gem tries to create meaningful transaction names from controller+action
      # or something similar depending on the framework used. However, you may want to override the
      # transaction name to better describe your instrumented operation.
      #
      # === Argument:
      #
      # * +custom_name+ - A non-empty string with the custom transaction name
      #
      # === Example:
      #
      #   class DogfoodsController < ApplicationController
      #
      #     def create
      #       @dogfood = Dogfood.new(params.permit(:brand, :name))
      #       @dogfood.save
      #
      #       SolarWindsAPM::API.set_transaction_name("dogfoodscontroller.create_for_#{params[:brand]}")
      #
      #       redirect_to @dogfood
      #     end
      #
      #   end
      #
      # === Returns:
      # * Boolean
      #
      def set_transaction_name(custom_name=nil)
        
        return false if custom_name.nil? || custom_name.empty? 

        solarwinds_processor = SolarWindsAPM::OTelConfig.class_variable_get(:@@config)[:span_processor]
        if solarwinds_processor.nil?
          SolarWindsAPM.logger.warn {"[#{name}/#{__method__}] Solarwinds processor is missing. Set transaction name failed."}
          return false
        end

        entry_trace_id = ::OpenTelemetry::Baggage.value(::SolarWindsAPM::Constants::INTL_SWO_CURRENT_TRACE_ID)
        entry_span_id  = ::OpenTelemetry::Baggage.value(::SolarWindsAPM::Constants::INTL_SWO_CURRENT_SPAN_ID)

        if entry_trace_id.nil? || entry_span_id.nil? 
          SolarWindsAPM.logger.warn {"[#{name}/#{__method__}] Cannot cache custom transaction name #{custom_name} because OTel service entry span not started; ignoring"}
          return false
        end

        trace_span_id = "#{entry_trace_id}-#{entry_span_id}"
        solarwinds_processor.txn_manager.set(trace_span_id,custom_name) 
        SolarWindsAPM.logger.debug {"[#{name}/#{__method__}] Cached custom transaction name for #{trace_span_id} as #{custom_name}"}
        true
      end
    end
  end
end
