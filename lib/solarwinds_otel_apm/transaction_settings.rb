# Copyright (c) 2018 SolarWinds, LLC.
# All rights reserved.
#

SWO_TRACING_ENABLED      = 1
SWO_TRACING_DISABLED     = 0
SWO_TRACING_UNSET        = -1
SWO_TRACING_DECISIONS_OK = 0
OBOE_SETTINGS_UNSET      = -1

module SolarWindsOTelAPM
  ##
  # This module helps with setting up the transaction filters and applying them
  #
  class TransactionSettings
    def initialize(url: '', name: '', kind: '')
      @url = url
      @name = name
      @kind = kind
    end

    # kind: url/spankind
    def calculate_trace_mode(kind: nil)
      cvalue = kind == 'url' ? @url : "#{@name}:#{@kind}"
      tracing_mode_enabled? && tracing_enabled?(cvalue, kind: kind) ? SWO_TRACING_ENABLED : SWO_TRACING_DISABLED
    end

    private

    def tracing_mode_enabled?
      SolarWindsOTelAPM::Config[:tracing_mode] && ![:disabled, :never].include?(SolarWindsOTelAPM::Config[:tracing_mode])
    end

    def tracing_enabled?(value, kind: nil)
      enabled_regexps = kind == 'url' ? SolarWindsOTelAPM::Config[:url_enabled_regexps] : SolarWindsOTelAPM::Config[:spankind_enabled_regexps]
      disabled_regexps = kind == 'url' ? SolarWindsOTelAPM::Config[:url_disabled_regexps] : SolarWindsOTelAPM::Config[:spankind_disabled_regexps]

      if disabled_regexps.is_a?(Array) && disabled_regexps.any? { |regex| regex.match?(value) }
        false
      elsif enabled_regexps.is_a?(Array) && enabled_regexps.any? { |regex| regex.match?(value) }
        true
      else
        enabled_regexps.nil? ? true : enabled_regexps.empty?  # permit by default if no regexps are defined
      end
    rescue StandardError => e
      SolarWindsOTelAPM.logger.warn "[SolarWindsOTelAPM/filter_error] Could not determine tracing status for #{kind}. #{e.inspect}"
      false
    end


    class << self
      def compile_settings(settings, kind: nil)
        if !settings.is_a?(Array) || settings.empty?
          kind == 'url' ? reset_url_regexps : reset_spankind_regexps
          return
        end

        # `tracing: disabled` is the default
        disabled = settings.select { |v| !v.has_key?(:tracing) || v[:tracing] == :disabled }
        enabled = settings.select { |v| v[:tracing] == :enabled }

        case kind
        when 'url'
          SolarWindsOTelAPM::Config[:url_enabled_regexps] = compile_regexp(enabled)
          SolarWindsOTelAPM::Config[:url_disabled_regexps] = compile_regexp(disabled)
        when 'spankind'
          SolarWindsOTelAPM::Config[:spankind_enabled_regexps] = compile_regexp(enabled)
          SolarWindsOTelAPM::Config[:spankind_disabled_regexps] = compile_regexp(disabled)
        end
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

      def reset_url_regexps
        SolarWindsOTelAPM::Config[:url_enabled_regexps] = nil
        SolarWindsOTelAPM::Config[:url_disabled_regexps] = nil
      end

      def reset_spankind_regexps
        SolarWindsOTelAPM::Config[:spankind_enabled_regexps] = nil
        SolarWindsOTelAPM::Config[:spankind_disabled_regexps] = nil
      end
    end
  end
end
