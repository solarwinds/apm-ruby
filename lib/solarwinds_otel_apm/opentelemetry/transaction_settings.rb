# Copyright (c) 2018 SolarWinds, LLC.
# All rights reserved.
#
module SolarWindsOTelAPM
  ##
  # This module helps with setting up the transaction filters and applying them
  #
  class TransactionSettings
    SWO_TRACING_ENABLED      = 1
    SWO_TRACING_DISABLED     = 0

    def initialize(url: '', name: '', kind: '')
      @url = url
      @name = name
      @kind = kind
    end

    # calculate trace mode to set either 1 or 0 based on url and name+kind
    # first check if url match, if not match, then match the name+kind
    def calculate_trace_mode
      tracing_mode_enabled? && tracing_enabled? ? SWO_TRACING_ENABLED : SWO_TRACING_DISABLED
    end

    private

    def tracing_mode_enabled?
      SolarWindsOTelAPM::Config[:tracing_mode] && ![:disabled, :never].include?(SolarWindsOTelAPM::Config[:tracing_mode])
    end

    def tracing_enabled?
      span_layer = "#{@name}:#{@kind}"

      enabled_regexps = SolarWindsOTelAPM::Config[:enabled_regexps]
      disabled_regexps = SolarWindsOTelAPM::Config[:disabled_regexps]

      SolarWindsOTelAPM.logger.debug "[solarwinds_otel_apm/transaction_settings] enabled_regexps: #{enabled_regexps&.inspect}"
      SolarWindsOTelAPM.logger.debug "[solarwinds_otel_apm/transaction_settings] disabled_regexps: #{disabled_regexps&.inspect}"

      return false if disabled_regexps.is_a?(Array) && disabled_regexps.any? { |regex| regex.match?(@url) }
      return true if enabled_regexps.is_a?(Array) && enabled_regexps.any? { |regex| regex.match?(@url) }
      return false if disabled_regexps.is_a?(Array) && disabled_regexps.any? { |regex| regex.match?(span_layer) }
      return true if enabled_regexps.is_a?(Array) && enabled_regexps.any? { |regex| regex.match?(span_layer) }

      true
    rescue StandardError => e
      SolarWindsOTelAPM.logger.warn "[SolarWindsOTelAPM/filter_error] Could not determine tracing status for #{kind}. #{e.inspect}. transaction_settings regexps/extensions igonred/unfiltered."
      true
    end
  end
end
