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

    # cache can only be done in liboboe level because each agent is independent among all the app
    # p.s. should_sample? call sequence is instrumentation start_root_span/start_span -> @tracer_provider.internal_start_span -> should_sample?
    # but still can provide a cache that avoid each time to run following code over and over
    def calculate_trace_mode(kind: nil)
      cvalue = kind == 'url' ? @url : "#{@name}:#{@kind}"
      (tracing_mode_disabled? && !tracing_enabled?(cvalue, kind: kind) || tracing_disabled?(cvalue, kind: kind))? SWO_TRACING_DISABLED : SWO_TRACING_ENABLED
    end

    private

    def tracing_mode_disabled?
      SolarWindsOTelAPM::Config[:tracing_mode] && [:disabled, :never].include?(SolarWindsOTelAPM::Config[:tracing_mode])
    end

    ##
    # tracing_enabled?
    #
    # Given a path/spankind, this method determines whether it matches any of the
    # regexps to exclude it from metrics and traces
    #
    def tracing_enabled?(value, kind: nil)
      regexp_group = kind == 'url' ? SolarWindsOTelAPM::Config[:url_enabled_regexps] : SolarWindsOTelAPM::Config[:spankind_enabled_regexps]
      return false unless regexp_group.is_a? Array
      return true if regexp_group.empty?  # if array doesn't contain anything, then it's permit by default
      return regexp_group.any? { |regex| regex.match?(value) }
    rescue StandardError => e
      SolarWindsOTelAPM.logger.warn "[SolarWindsOTelAPM/filter] Could not apply :enabled filter to #{kind}. #{e.inspect}"
      true
    end

    ##
    # tracing_disabled?
    #
    # Given a path or spankind, this method determines whether it matches any of the
    # regexps to exclude it from metrics and traces
    #
    def tracing_disabled?(value, kind: nil)
      regexp_group = kind == 'url' ? SolarWindsOTelAPM::Config[:url_disabled_regexps] : SolarWindsOTelAPM::Config[:spankind_disabled_regexps]
      return false unless regexp_group.is_a? Array
      return false if regexp_group.empty?
      return regexp_group.any? { |regex| regex.match?(value) }
    rescue StandardError => e
      SolarWindsOTelAPM.logger.warn "[SolarWindsOTelAPM/filter] Could not apply :disabled filter to #{kind}. #{e.inspect}"
      false
    end

    public

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
          v.key?(:regexp) &&
            !(v[:regexp].is_a?(String) && v[:regexp].empty?) &&
            !(v[:regexp].is_a?(Regexp) && v[:regexp].inspect == '//')
        end

        regexps.map! do |v|
          begin
            v[:regexp].is_a?(String) ? Regexp.new(v[:regexp], v[:opts]) : Regexp.new(v[:regexp])
          rescue
            SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/config] Problem compiling transaction_settings item #{v}, will ignore."
            nil
          end
        end
        regexps.keep_if { |v| !v.nil? }
        regexps.empty? ? nil : regexps
      end

      def compile_settings_extensions(value)
        extensions = value.select do |v|
          v.key?(:extensions) &&
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
