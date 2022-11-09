# solarwinds_nh will use liboboe to export data to solarwinds swo

module SolarWindsOTelAPM
  module OpenTelemetry
    class SolarWindsExporter


      SUCCESS = ::OpenTelemetry::SDK::Trace::Export::SUCCESS # ::OpenTelemetry  #=> the OpenTelemetry at top level (to ignore SolarWindsOTelAPM)
      FAILURE = ::OpenTelemetry::SDK::Trace::Export::FAILURE
      private_constant(:SUCCESS, :FAILURE)
    
      def initialize(endpoint: ENV['SW_APM_EXPORTER'],
                     metrics_reporter: nil,
                     service_key: ENV['SW_APM_SERVICE_KEY']
                     )
        raise ArgumentError, "Missing SW_APM_SERVICE_KEY." if service_key.nil?
        
        @metrics_reporter = metrics_reporter || ::OpenTelemetry::SDK::Trace::Export::MetricsReporter
        @shutdown = false
      end

      def export(span_data, timeout: nil)
        SolarWindsOTelAPM.logger.debug "#{@shutdown}" 
        return FAILURE if @shutdown
        span_data.each do |data|
          log_span_data(data)
          break
        end
        span_data = span_data.first
        SUCCESS
      end

      def force_flush(timeout: nil)
        SUCCESS
      end

      def shutdown(timeout: nil)
        @shutdown = true
        SUCCESS
      end

      private

      def log_span_data(span_data)

        begin
          flag = 0
          flag = 1 if span_data.trace_flags.sampled?
          version = "00"
          xtr = "#{version}-#{span_data.hex_trace_id}-#{span_data.hex_span_id}-0#{flag}"
          md = SolarWindsOTelAPM::Metadata.fromString(xtr)
          event = SolarWindsOTelAPM::Context.createEntry(md,span_data.start_timestamp.to_i / 1000)

          trace_span_id = "#{span_data.hex_trace_id}-#{span_data.hex_span_id}"
          txname = "sample_trace"
          event.addInfo("TransactionName", txname)

          event.addInfo('Layer', span_data.name)
          event.addInfo('Kind', span_data.kind.to_s)
          event.addInfo('Language', 'Ruby')
          SolarWindsOTelAPM::Reporter.sendReport(event)
          if span_data.name == 'exception'
            report_exception_event(span_data)
          else
            report_info_event(span_data)
          end

          event = SolarWindsOTelAPM::Context.createExit((span_data.end_timestamp.to_i / 1000))
          event.addInfo('Layer', span_data.name)

          SolarWindsOTelAPM::Reporter.sendReport(event)
        rescue Exception => e
          SolarWindsOTelAPM.logger.debug "######## \n\n #{e.message} #{e.backtrace}\n\n ########"
          raise
        end

      end

      def report_exception_event(span_data)

        evt = SolarWindsOTelAPM::Context.createEvent(span_data.end_timestamp.to_i / 1000 )
        evt.addInfo('Label', 'error')
        evt.addInfo('Spec', 'error')
        evt.addInfo('ErrorClass', span_data.attributes['exception.type'])
        evt.addInfo('ErrorMsg', span_data.attributes['exception.message'])
        evt.addInfo('Backtrace', span_data.attributes['exception.stacktrace'])
        # add remaining attributes, if any
        span_data.resource.attribute_enumerator.each do |key, value|
          unless ['exception.type', 'exception.message','exception.stacktrace'].include? key
            evt.addInfo(key, value)
          end
        end
        SolarWindsOTelAPM::Reporter.sendReport(evt)

      end

      def report_info_event(span_data)
        
        evt = SolarWindsOTelAPM::Context.createEvent(span_data.end_timestamp.to_i / 1000 )
        evt.addInfo('Label', 'info')
        span_data.resource.attribute_enumerator.each do |key, value|
          evt.addInfo(key, value)
        end
        SolarWindsOTelAPM::Reporter.sendReport(evt)
      end

      def encoded_batches(span_data)
        span_data.group_by(&:resource).map do |resource, spans|
          process = Encoder.encoded_process(resource)
          spans.map! { |span| Encoder.encoded_span(span) }
          Thrift::Batch.new('process' => process, 'spans' => spans)
        end
      end

      def measure_request_duration
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        yield
      ensure
        stop = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        duration_ms = 1000.0 * (stop - start)
        @metrics_reporter.record_value('solarwinds_apm.request_duration', value: duration_ms)
      end

    end
  end
end



