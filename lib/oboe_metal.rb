# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

# Disable docs and Camelcase warns since we're implementing
# an interface here.  See OboeBase for details.
module SolarWindsAPM
  extend SolarWindsAPMBase
  include Oboe_metal

  # Reporter that send span data to SWO
  class Reporter
    class << self
      ##
      # start
      #
      # Start the SolarWindsAPM Reporter
      #
      def start
        SolarWindsAPM.loaded = false unless SolarWindsAPM::OboeInitOptions.instance.service_key_ok?
        return unless SolarWindsAPM.loaded

        begin
          options = SolarWindsAPM::OboeInitOptions.instance.array_for_oboe # creates an array with the options in the right order

          SolarWindsAPM.reporter = Oboe_metal::Reporter.new(*options)

          report_init
        rescue StandardError=> e
          $stderr.puts e.message
          raise
        end
      end
      alias :restart :start

      ##
      # sendReport
      #
      # Send the report for the given event
      #
      def send_report(evt, with_system_timestamp: true)
        SolarWindsAPM.reporter.sendReport(evt, with_system_timestamp)
      end

      ##
      # sendStatus
      #
      # Send the report for the given event
      #
      def send_status(evt, context=nil, with_system_timestamp: true)
        SolarWindsAPM.reporter.sendStatus(evt, context, with_system_timestamp)
      end

      ##
      # clear_all_traces
      #
      # Truncates the trace output file to zero
      #
      def clear_all_traces
        File.truncate(SolarWindsAPM::OboeInitOptions.instance.host, 0)
      end

      ##
      # obtain_all_traces
      #
      # Retrieves all traces written to the trace file
      #
      def obtain_all_traces
        io = File.open(SolarWindsAPM::OboeInitOptions.instance.host, 'r')
        contents = io.readlines(nil)
        io.close

        return contents if contents.empty?

        traces = []

        # We use Gem.loaded_spec because older versions of the bson
        # gem didn't even have a version embedded in the gem.  If the
        # gem isn't in the bundle, it should rightfully error out
        # anyways.
        #
        if Gem.loaded_specs['bson'] && Gem.loaded_specs['bson'].version.to_s < '4.0'
          s = StringIO.new(contents[0])

          until s.eof?
            traces << if ::BSON.respond_to? :read_bson_document
                        BSON.read_bson_document(s)
                      else
                        BSON::Document.from_bson(s)
                      end
          end
        else
          bbb = ::BSON::ByteBuffer.new(contents[0])
          traces << Hash.from_bson(bbb) until bbb.length == 0
        end

        traces
      end

      private
      
      # Internal: Report that instrumentation for the given layer has been
      # installed, as well as the version of instrumentation and version of
      # layer.
      #
      def report_init(layer=:rack) # :nodoc:
        # Don't send __Init in test or if SolarWindsAPM
        # isn't fully loaded (e.g. missing c-extension)
        return if ENV.has_key?('SW_APM_GEM_TEST') || !SolarWindsAPM.loaded

        platform_info = build_swo_init_report
        log_init(layer, platform_info)
      end

      ##
      # :nodoc:
      # Internal: Reports agent init to the collector
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +kvs+ - A hash containing key/value pairs that will be reported along with this event
      def log_init(layer=:rack, kvs={})
        context = SolarWindsAPM::Metadata.makeRandom
        return SolarWindsAPM::Context.toString unless context.isValid

        event = context.createEvent
        event.addInfo('Layer', layer.to_s)
        event.addInfo('Label', 'single')
        kvs.each do |k, v|
          event.addInfo(k, v.to_s)
        end

        SolarWindsAPM::Reporter.send_status(event, context, with_system_timestamp: true)
        SolarWindsAPM::Context.toString
      end

      ##
      #  build_swo_init_report
      #
      # Internal: Build a hash of KVs that reports on the status of the
      # running environment for swo only. This is used on stack boot in __Init reporting
      # and for SolarWindsAPM.support_report.
      #
      def build_swo_init_report

        platform_info = {'__Init' => true}

        begin
          platform_info['APM.Version']             = SolarWindsAPM::Version::STRING
          platform_info['APM.Extension.Version']   = extension_lib_version
          
          # OTel Resource Attributes (Optional)
          platform_info['process.executable.path'] = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name']).sub(/.*\s.*/m, '"\&"')
          platform_info['process.executable.name'] = RbConfig::CONFIG['ruby_install_name']
          platform_info['process.command_line']    = $PROGRAM_NAME
          platform_info['process.telemetry.path']  = Gem::Specification.find_by_name('solarwinds_apm')&.full_gem_path
          platform_info['os.type']                 = RUBY_PLATFORM

          platform_info.merge!(report_gem_in_use)

          # Collect up opentelemetry sdk version (Instrumented Library Versions) (Required)
          begin
            require 'opentelemetry/sdk'
            ::OpenTelemetry::SDK::Resources::Resource.telemetry_sdk.attribute_enumerator.each {|k,v| platform_info[k] = v}
            ::OpenTelemetry::SDK::Resources::Resource.process.attribute_enumerator.each {|k,v| platform_info[k] = v}
          rescue StandardError => e
            SolarWindsAPM.logger.warn {"[#{self.class}/#{__method__}] Fail to extract telemetry attributes. Error: #{e.message}"}
          end
        rescue StandardError, ScriptError => e
          # Also rescue ScriptError (aka SyntaxError) in case one of the expected
          # version defines don't exist

          platform_info['Error'] = "Error in build_report: #{e.message}"

          SolarWindsAPM.logger.warn {"[#{self.class}/#{__method__}] Error in build_init_report: #{e.message}"}
          SolarWindsAPM.logger.debug {e.backtrace}
        end
        platform_info
      end

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
        gem_location = Gem::Specification.find_by_name('solarwinds_apm')
        clib_version_file = File.join(gem_location&.gem_dir, 'ext', 'oboe_metal', 'src', 'VERSION')
        File.read(clib_version_file).strip
      end
    end
  end

  class << self
    def sample_rate(rate)
      return unless SolarWindsAPM.loaded

      # Update liboboe with the new SampleRate value
      SolarWindsAPM::Context.setDefaultSampleRate(rate.to_i)
    end
  end
end

SolarWindsAPM.loaded = true
# rubocop:enable Style/Documentation