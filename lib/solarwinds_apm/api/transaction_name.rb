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
        status = true
        if custom_name.nil? || custom_name.empty?
          SolarWindsAPM.logger.warn {"[#{name}/#{__method__}] Set transaction name failed: custom_name is either nil or empty string."}
          status = false
        elsif SolarWindsAPM::OTelConfig.class_variable_get(:@@config)[:span_processor].nil?
          SolarWindsAPM.logger.warn {"[#{name}/#{__method__}] Set transaction name failed: Solarwinds processor is missing."}
          status = false
        elsif SolarWindsAPM::Context.toString == '99-00000000000000000000000000000000-0000000000000000-00'
          # noop mode, just log and skip work
          SolarWindsAPM.logger.debug {"[#{name}/#{__method__}] SolarWindsAPM is in noop mode."}
        else
          solarwinds_processor = SolarWindsAPM::OTelConfig.class_variable_get(:@@config)[:span_processor]
          current_span         = ::OpenTelemetry::Trace.current_span

          if current_span.context.valid?
            current_trace_id = current_span.context.hex_trace_id
            entry_span_id, trace_flags = solarwinds_processor.txn_manager.get_root_context_h(current_trace_id)&.split('-')
            if entry_span_id.to_s.empty? || trace_flags.to_s.empty?
              SolarWindsAPM.logger.warn {"[#{name}/#{__method__}] Set transaction name failed: record not found in the transaction manager."}
              status = false
            else
              solarwinds_processor.txn_manager.set("#{current_trace_id}-#{entry_span_id}",custom_name)
              SolarWindsAPM.logger.debug {"[#{name}/#{__method__}] Cached custom transaction name for #{entry_trace_id}-#{entry_span_id} as #{custom_name}"}
            end
          else
            SolarWindsAPM.logger.warn {"[#{name}/#{__method__}] Set transaction name failed: invalid span context."}
            status = false
          end
        end
        status
      end
    end
  end
end
