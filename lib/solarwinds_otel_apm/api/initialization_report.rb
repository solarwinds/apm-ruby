# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsOTelAPM
  module API
    module InitializationReport
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
            require 'opentelemetry/sdk'
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
