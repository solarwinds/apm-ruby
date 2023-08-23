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
      # ERROR -- : OpenTelemetry error: calls to detach should match corresponding calls to attach.
      def set_transaction_name(custom_name=nil)
        
        status = true
        if custom_name.nil? || custom_name.empty? 
          status = false
        elsif SolarWindsAPM::Context.toString == '99-00000000000000000000000000000000-0000000000000000-00' # noop
          status = true
        else
          solarwinds_processor = SolarWindsAPM::OTelConfig.class_variable_get(:@@config)[:span_processor]
          if solarwinds_processor.nil?
            SolarWindsAPM.logger.warn {"[#{name}/#{__method__}] Solarwinds processor is missing. Set transaction name failed."}
            status = false
          else
            entry_trace_id, entry_span_id, trace_flags = ::OpenTelemetry::Baggage.value(::SolarWindsAPM::Constants::INTL_SWO_CURRENT_TRACE_INFO)&.split("-")

            status = false if entry_trace_id.nil? || entry_span_id.nil? || trace_flags.nil?
            status = false if entry_trace_id == '0'*32 || entry_span_id == '0'*16 || trace_flags == '00' # not sampled

            solarwinds_processor.txn_manager.set("#{entry_trace_id}-#{entry_span_id}",custom_name) 
            SolarWindsAPM.logger.debug {"[#{name}/#{__method__}] Cached custom transaction name for #{entry_trace_id}-#{entry_span_id} as #{custom_name}"}
          end
        end
        status
      end
    end
  end
end
