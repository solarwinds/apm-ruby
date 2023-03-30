# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsOTelAPM
  ##
  # Provides utility methods for use while in the business
  # of instrumenting code
  module Util
    class << self
      def contextual_name(cls)
        # Attempt to infer a contextual name if not indicated
        #
        # For example:
        # ::ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter.to_s.split(/::/).last
        # => "AbstractMysqlAdapter"
        #
        cls.to_s.split(/::/).last
      rescue StandardError => e
        SolarWindsOTelAPM.logger.warn "[solarwinds_apm/loading] Couldn't contextual_name #{cls} with error #{e.message}." 
        cls
      end
      
      ##
      # send_extend
      #
      # Centralized utility method to send an extend call for an
      # arbitrary class
      def send_extend(target_cls, cls)
        target_cls.send(:extend, cls) if defined?(target_cls)
      end

      ##
      # send_include
      #
      # Centralized utility method to send a include call for an
      # arbitrary class
      def send_include(target_cls, cls)
        target_cls.send(:include, cls) if defined?(target_cls)
      end

      ##
      # prettify
      #
      # Even to my surprise, 'prettify' is a real word:
      # transitive v. To make pretty or prettier, especially in a superficial or insubstantial way.
      #   from The American Heritage Dictionary of the English Language, 4th Edition
      #
      # This method makes things 'purty' for reporting.
      def prettify(str)
        if (str.to_s =~ /^#</) == 0
          str.class.to_s
        else
          str.to_s
        end
      end

      ##
      # upcase
      #
      # Occasionally, we want to send some values in all caps.  This is true
      # for things like HTTP scheme or method.  This takes anything and does
      # it's best to safely convert it to a string (if needed) and convert it
      # to all uppercase.
      def upcase!(str)
        if str.is_a?(String) || str.respond_to?(:to_s)
          str.to_s.upcase
        else
          SolarWindsOTelAPM.logger.debug "[solarwinds_apm/debug] SolarWindsOTelAPM::Util.upcase: could not convert #{o.class}"
          'UNKNOWN'
        end
      end

      ##
      # to_query
      #
      # Used to convert a hash into a URL # query.
      #
      def to_query(hash_)
        return '' unless hash_.is_a?(Hash)

        result = []
        hash_.each {|k, v| result.push("#{k}=#{v}")}
        result.sort.join('&')
      end

      ##
      # sanitize_sql
      #
      # Remove query literals from SQL. Used by all
      # DB adapter instrumentation.
      #
      # The regular expression passed to String.gsub is configurable
      # via SolarWindsOTelAPM::Config[:sanitize_sql_regexp] and
      # SolarWindsOTelAPM::Config[:sanitize_sql_opts].
      #
      def sanitize_sql(sql)
        return sql unless SolarWindsOTelAPM::Config[:sanitize_sql]

        @@regexp ||= Regexp.new(SolarWindsOTelAPM::Config[:sanitize_sql_regexp], SolarWindsOTelAPM::Config[:sanitize_sql_opts]).freeze
        sql.gsub(/\\\'/,'').gsub(@@regexp, '?')
      end

      ##
      # remove_traceparent
      #
      # Remove trace context injection
      #
      def remove_traceparent(sql)
        sql.gsub(SolarWindsOTelAPM::SDK::CurrentTraceInfo::TraceInfo::SQL_REGEX, '')
      end

      ##
      # deep_dup
      #
      # deep duplicate of array or hash
      #
      def deep_dup(obj)
        if obj.is_a? Array
          new_obj = []
          obj.each do |v|
            new_obj << deep_dup(v)
          end
        elsif obj.is_a? Hash
          new_obj = {}
          obj.each_pair do |key, value|
            new_obj[key] = deep_dup(value)
          end
        end
      end

      ##
      #  build_swo_init_report
      #
      # Internal: Build a hash of KVs that reports on the status of the
      # running environment for swo only. This is used on stack boot in __Init reporting
      # and for SolarWindsOTelAPM.support_report.
      #
      def build_swo_init_report

        platform_info = {'__Init' => true}

        begin
          platform_info['APM.Version']             = SolarWindsOTelAPM::Version::STRING
          platform_info['APM.Extension.Version']   = extension_lib_version
          
          # OTel Resource Attributes (Optional)
          platform_info['process.executable.path'] = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name']).sub(/.*\s.*/m, '"\&"')
          platform_info['process.executable.name'] = RbConfig::CONFIG['ruby_install_name']
          platform_info['process.command_line']    = $PROGRAM_NAME
          platform_info['process.telemetry.path']  = Gem::Specification.find_by_name('solarwinds_otel_apm')&.full_gem_path
          platform_info['os.type']                 = RUBY_PLATFORM

          platform_info.merge!(report_gem_in_use)

          # Collect up opentelemetry sdk version (Instrumented Library Versions) (Required)
          begin
            ::OpenTelemetry::SDK::Resources::Resource.telemetry_sdk.attribute_enumerator.each {|k,v| platform_info[k] = v}
            ::OpenTelemetry::SDK::Resources::Resource.process.attribute_enumerator.each {|k,v| platform_info[k] = v}
          rescue StandardError => e
            SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/warn] Fail to extract telemetry attributes. Error: #{e.message}"
          end
        rescue StandardError, ScriptError => e
          # Also rescue ScriptError (aka SyntaxError) in case one of the expected
          # version defines don't exist

          platform_info['Error'] = "Error in build_report: #{e.message}"

          SolarWindsOTelAPM.logger.warn "[solarwinds_otel_apm/warn] Error in build_init_report: #{e.message}"
          SolarWindsOTelAPM.logger.debug e.backtrace
        end
        platform_info
      end

      private

      ##
      # Collect up the loaded gems
      ##
      def report_gem_in_use
        platform_info = {}
        if defined?(Gem) && Gem.respond_to?(:loaded_specs)
          Gem.loaded_specs.each_pair {|k, v| platform_info["Ruby.#{k}.Version"] = v.version.to_s}
        else
          platform_info.merge!(legacy_build_init_report)
        end
        platform_info
      end

      ##
      # get extension library version by looking at the VERSION file
      # oboe not loaded yet, can't use oboe_api function to read oboe VERSION
      ##
      def extension_lib_version
        gem_location = Gem::Specification.find_by_name('solarwinds_otel_apm')
        clib_version_file = File.join(gem_location&.gem_dir, 'ext', 'oboe_metal', 'src', 'VERSION')
        File.read(clib_version_file).strip
      end
    end
  end
end
