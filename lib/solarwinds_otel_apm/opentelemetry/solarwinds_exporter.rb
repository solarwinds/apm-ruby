# solarwinds_nh will use liboboe to export data to solarwinds swo

module SolarWindsOTelAPM
  module OpenTelemetry
    class SolarWindsExporter


      SUCCESS = ::OpenTelemetry::SDK::Trace::Export::SUCCESS # ::OpenTelemetry  #=> the OpenTelemetry at top level (to ignore SolarWindsOTelAPM)
      FAILURE = ::OpenTelemetry::SDK::Trace::Export::FAILURE
      private_constant(:SUCCESS, :FAILURE)
    
      def initialize(endpoint: ENV['SW_APM_EXPORTER'],
                     metrics_reporter: nil,
                     service_key: ENV['SW_APM_SERVICE_KEY'],
                     apm_txname_manager: nil)
        raise ArgumentError, "Missing SW_APM_SERVICE_KEY." if service_key.nil?
        
        @metrics_reporter = metrics_reporter || ::OpenTelemetry::SDK::Trace::Export::MetricsReporter
        @shutdown = false
        @apm_txname_manager = apm_txname_manager
        @context = SolarWindsOTelAPM::Context
        @metadata = SolarWindsOTelAPM::Metadata
        @reporter = SolarWindsOTelAPM::Reporter
      end

      def export(span_data, timeout: nil)
        return FAILURE if @shutdown
        SolarWindsOTelAPM.logger.debug "####### span_data: #{span_data} " 
        span_data.each do |data|
          log_span_data(data)
        end
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
          md = build_meta_data(span_data)
          event = nil

          if span_data.parent_span_id != ::OpenTelemetry::Trace::INVALID_SPAN_ID 
            # child span

            parent_md = build_meta_data(span_data, true)
            SolarWindsOTelAPM.logger.debug "Continue trace from parent. parent_md: #{parent_md}, span_data: #{span_data.inspect}"
            event = @context.createEntry(md, (span_data.start_timestamp.to_i / 1000).to_i, parent_md)
            # if parent_span_context.remote?
            #   add_info_transaction_name(span_data, event) 

          else

            SolarWindsOTelAPM.logger.debug "#######  Start a new trace."
            event = @context.createEntry(md, (span_data.start_timestamp.to_i / 1000).to_i) 
            add_info_transaction_name(span_data, event)
          end
          
          event.addInfo('Layer', span_data.name)
          event.addInfo('Kind', span_data.kind.to_s)
          event.addInfo('Language', 'Ruby')

          # info event
          SolarWindsOTelAPM.logger.debug "####### event (info/error event): #{event.metadataString}"
          @reporter.sendReport(event, false)
          if span_data.name == 'exception'
            report_exception_event(span_data)
          else
            report_info_event(span_data)
          end

          # exit event
          event = @context.createExit((span_data.end_timestamp.to_i / 1000).to_i)
          event.addInfo('Layer', span_data.name)
          SolarWindsOTelAPM.logger.debug "####### event (exit): #{event.metadataString}"
          @reporter.sendReport(event, false)
        rescue Exception => e
          SolarWindsOTelAPM.logger.debug "######## \n\n #{e.message} #{e.backtrace}\n\n ########"
          raise
        end

      end

      # Add transaction name from cache to root span then removes from cache
      def add_info_transaction_name span_data, evt
        trace_span_id = "#{span_data.hex_trace_id}-#{span_data.hex_span_id}"
        SolarWindsOTelAPM.logger.debug "#{@apm_txname_manager.inspect},\n span_data: #{span_data.inspect}"
        txname = @apm_txname_manager.get(trace_span_id).nil?? "" : @apm_txname_manager.get(trace_span_id)
        SolarWindsOTelAPM.logger.debug "######## txname #{txname} ########"
        evt.addInfo("TransactionName", txname)
        @apm_txname_manager.del(trace_span_id)
      end

      def report_exception_event(span_data)

        evt = @context.createEvent((span_data.end_timestamp.to_i / 1000).to_i)
        evt.addInfo('Label', 'error')
        evt.addInfo('Spec', 'error')
        evt.addInfo('ErrorClass', span_data.attributes['exception.type'])
        evt.addInfo('ErrorMsg', span_data.attributes['exception.message'])
        evt.addInfo('Backtrace', span_data.attributes['exception.stacktrace'])
        span_data.resource.attribute_enumerator.each do |key, value|
          unless ['exception.type', 'exception.message','exception.stacktrace'].include? key
            evt.addInfo(key, value)
          end
        end
        @reporter.sendReport(evt, false)

      end

      def report_info_event(span_data)
        evt = SolarWindsOTelAPM::Context.createEvent((span_data.end_timestamp.to_i / 1000).to_i)
        evt.addInfo('Label', 'info')
        span_data.resource.attribute_enumerator.each do |key, value|
          evt.addInfo(key, value)
        end
        @reporter.sendReport(evt, false)
      end

      def build_meta_data span_data, parent=false
        flag = span_data.trace_flags.sampled?? 1 : 0
        version = "00"
        xtr = (parent == false)? "#{version}-#{span_data.hex_trace_id}-#{span_data.hex_span_id}-0#{flag}" : "#{version}-#{span_data.hex_trace_id}-#{span_data.hex_parent_span_id}-0#{flag}"
        md = @metadata.fromString(xtr)
        return md
      end

    end
  end
end



