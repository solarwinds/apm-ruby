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

    class << self
      def compile_settings(settings)
        if !settings.is_a?(Array) || settings.empty?
          reset_regexps
          return
        end

        # `tracing: disabled` is the default
        disabled = settings.select { |v| !v.has_key?(:tracing) || v[:tracing] == :disabled }
        enabled = settings.select { |v| v[:tracing] == :enabled }

        SolarWindsOTelAPM::Config[:enabled_regexps] = compile_regexp(enabled)
        SolarWindsOTelAPM::Config[:disabled_regexps] = compile_regexp(disabled)
      end

      def compile_regexp(settings)
        regexp_regexp     = compile_settings_regexp(settings)
        extensions_regexp = compile_settings_extensions(settings)

        regexps = [regexp_regexp, extensions_regexp].flatten.compact

        regexps.empty? ? nil : regexps
      end

      def compile_settings_regexp(value)
        regexps = value.select do |v|
          v.has_key?(:regexp) &&
            !(v[:regexp].is_a?(String) && v[:regexp].empty?) &&
            !(v[:regexp].is_a?(Regexp) && v[:regexp].inspect == '//')
        end

        regexps.map! do |v|
          begin
            v[:regexp].is_a?(String) ? Regexp.new(v[:regexp], v[:opts]) : Regexp.new(v[:regexp])
          rescue StandardError => e
            SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/config] Problem compiling transaction_settings item #{v}, will ignore. Error: #{e.message}"
            nil
          end
        end
        regexps.keep_if { |v| !v.nil? }
        regexps.empty? ? nil : regexps
      end

      def compile_settings_extensions(value)
        extensions = value.select do |v|
          v.has_key?(:extensions) &&
            v[:extensions].is_a?(Array) &&
            !v[:extensions].empty?
        end
        extensions = extensions.map { |v| v[:extensions] }.flatten
        extensions.keep_if { |v| v.is_a?(String) }

        extensions.empty? ? nil : Regexp.new("(#{Regexp.union(extensions).source})(\\?.+){0,1}$")
      end

      def reset_regexps
        SolarWindsOTelAPM::Config[:enabled_regexps] = nil
        SolarWindsOTelAPM::Config[:disabled_regexps] = nil
      end

    end
  end
end
