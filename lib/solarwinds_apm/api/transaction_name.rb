# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

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
      def set_transaction_name(custom_name = nil)
        status = true
        if ENV.fetch('SW_APM_ENABLED', 'true') == 'false' ||
           SolarWindsAPM::Context.toString == '99-00000000000000000000000000000000-0000000000000000-00'
          # library disabled or noop, just log and skip work.
          # TODO: can we have a single indicator that the API is in noop mode?
          SolarWindsAPM.logger.debug { "[#{name}/#{__method__}] SolarWindsAPM is in disabled or noop mode." }
        elsif custom_name.nil? || custom_name.empty?
          SolarWindsAPM.logger.warn do
            "[#{name}/#{__method__}] Set transaction name failed: custom_name is either nil or empty string."
          end
          status = false
        elsif SolarWindsAPM::OTelNativeConfig[:metrics_processor].nil?
          SolarWindsAPM.logger.warn do
            "[#{name}/#{__method__}] Set transaction name failed: Solarwinds processor is missing."
          end
          status = false
        else
          solarwinds_processor = SolarWindsAPM::OTelNativeConfig[:metrics_processor]
          current_span = ::OpenTelemetry::Trace.current_span

          if current_span.context.valid?
            current_trace_id = current_span.context.hex_trace_id
            entry_span_id, trace_flags = solarwinds_processor.txn_manager.get_root_context_h(current_trace_id)&.split('-')
            if entry_span_id.to_s.empty? || trace_flags.to_s.empty?
              SolarWindsAPM.logger.warn do
                "[#{name}/#{__method__}] Set transaction name failed: record not found in the transaction manager."
              end
              status = false
            else
              solarwinds_processor.txn_manager.set("#{current_trace_id}-#{entry_span_id}", custom_name)
              SolarWindsAPM.logger.debug do
                "[#{name}/#{__method__}] Cached custom transaction name for #{current_trace_id}-#{entry_span_id} as #{custom_name}"
              end
            end
          else
            SolarWindsAPM.logger.warn { "[#{name}/#{__method__}] Set transaction name failed: invalid span context." }
            status = false
          end
        end
        status
      end
    end
  end
end
