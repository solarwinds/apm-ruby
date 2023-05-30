# Copyright (c) 2018 SolarWinds, LLC.
# All rights reserved.
#
module SolarWindsOTelAPM
  ##
  # This module helps with setting up the transaction filters and applying them
  #
  module API
    module TransactionSettings
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
