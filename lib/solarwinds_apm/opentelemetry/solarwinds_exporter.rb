# solarwinds_apm will use liboboe to export data to solarwinds swo
module SolarWindsAPM
  module OpenTelemetry
    # SolarWindsExporter
    class SolarWindsExporter
      SUCCESS = ::OpenTelemetry::SDK::Trace::Export::SUCCESS # ::OpenTelemetry  #=> the OpenTelemetry at top level (to ignore SolarWindsAPM)
      FAILURE = ::OpenTelemetry::SDK::Trace::Export::FAILURE

      private_constant(:SUCCESS, :FAILURE)
    
      def initialize(txn_manager: nil)
        @shutdown           = false
        @txn_manager        = txn_manager
        @reporter           = SolarWindsAPM::Reporter
        @context            = SolarWindsAPM::Context
        @metadata           = SolarWindsAPM::Metadata
        @version_cache      = {}
      end

      def export(span_data, _timeout: nil)
        return FAILURE if @shutdown
        
        SolarWindsAPM.logger.debug "####### span_data: #{span_data} " 
        span_data.each do |data|
          log_span_data(data)
        end
        SUCCESS
      end

      def force_flush(timeout: nil) # rubocop:disable Lint/UnusedMethodArgument
        SUCCESS
      end

      def shutdown(timeout: nil) # rubocop:disable Lint/UnusedMethodArgument
        @shutdown = true
        SUCCESS
      end

      private

      def log_span_data(span_data)

        begin
          md = build_meta_data(span_data)
          event = nil

          if span_data.parent_span_id != ::OpenTelemetry::Trace::INVALID_SPAN_ID 

            parent_md = build_meta_data(span_data, parent: true)
            SolarWindsAPM.logger.debug "Continue trace from parent. parent_md: #{parent_md}, span_data: #{span_data.inspect}"
            event = @context.createEntry(md, (span_data.start_timestamp.to_i / 1000).to_i, parent_md)
          else

            SolarWindsAPM.logger.debug "#######  Start a new trace."
            event = @context.createEntry(md, (span_data.start_timestamp.to_i / 1000).to_i) 
            add_info_transaction_name(span_data, event)
          end
          
          event.addInfo('Layer', span_data.name)
          event.addInfo('sw.span_kind', span_data.kind.to_s)
          event.addInfo('Language', 'Ruby')
          
          add_info_instrumentation_scope(event, span_data)
          add_info_instrumented_framework(event, span_data)

          if span_data.attributes
            if span_data.attributes['http.target']
              http_target = span_data.attributes['http.target']
              http_target = http_target.split('?').first if SolarWindsAPM::Config[:log_args] == false # remove url parameters
              event.addInfo('http.target', http_target)
              span_data.attributes.each do |k, v|
                next if k == 'http.target'
                
                event.addInfo(k, v)
              end
            else
              span_data.attributes.each { |k, v| event.addInfo(k, v) }
            end
          end

          @reporter.send_report(event, with_system_timestamp: false)

          # info / exception event
          span_data.events&.each do |span_data_event|
            span_data_event.name == 'exception' ? report_exception_event(span_data_event) : report_info_event(span_data_event)
          end

          event = @context.createExit((span_data.end_timestamp.to_i / 1000).to_i)
          event.addInfo('Layer', span_data.name)
          @reporter.send_report(event, with_system_timestamp: false)
          SolarWindsAPM.logger.debug "####### Exit a trace: #{event.metadataString}"
        rescue StandardError => e
          SolarWindsAPM.logger.debug "######## \n\n #{e.message} #{e.backtrace}\n\n ########"
          raise
        end

      end

      def add_info_instrumentation_scope(event, span_data)
        scope_name = ""
        scope_version = ""
        if span_data.instrumentation_scope
          scope_name = span_data.instrumentation_scope.name if span_data.instrumentation_scope.name
          scope_version = span_data.instrumentation_scope.version if span_data.instrumentation_scope.version
        end
        event.addInfo(SolarWindsAPM::Constants::INTL_SWO_OTEL_SCOPE_NAME, scope_name) 
        event.addInfo(SolarWindsAPM::Constants::INTL_SWO_OTEL_SCOPE_VERSION, scope_version)
      end

      # 
      # get the framework version (the real version not the sdk instrumentation version)
      # 
      def add_info_instrumented_framework(event, span_data)
        SolarWindsAPM.logger.debug "####### add_info_instrumented_framework: #{span_data.instrumentation_scope.name}"
        scope_name = span_data.instrumentation_scope.name
        scope_name = scope_name.downcase if scope_name
        return unless scope_name&.include? "opentelemetry::instrumentation"
          
        framework = scope_name.split("::")[2..]&.join("::")
        return if framework.nil? || framework.empty?
        
        framework         = normalize_framework_name(framework)
        framework_version = check_framework_version(framework)
        event.addInfo("Ruby.#{framework}.Version",framework_version) unless framework_version.nil?
      end

      def check_framework_version(framework)
        framework_version = nil
        if @version_cache.keys.include? framework

          framework_version = @version_cache[framework]
        else

          begin
            require framework
            framework_version = Gem.loaded_specs[framework].version.to_s
          rescue LoadError => e
            SolarWindsAPM.logger.debug "######## couldn't load #{framework} with error #{e.message}; skip ########" 
          rescue StandardError => e
            SolarWindsAPM.logger.debug "######## couldn't find #{framework} with error #{e.message}; skip ########" 
          ensure
            @version_cache[framework] = framework_version
          end
        end
        SolarWindsAPM.logger.debug "######## Current framework version cached: #{@version_cache.inspect}"
        framework_version
      end

      def normalize_framework_name(framework)
        case framework
        when "net::http"
          normalized = "net/http"
        else
          normalized = framework
        end
        normalized
      end

      # Add transaction name from cache to root span then removes from cache
      def add_info_transaction_name(span_data, evt)
        trace_span_id = "#{span_data.hex_trace_id}-#{span_data.hex_span_id}"
        SolarWindsAPM.logger.debug "#{@txn_manager.inspect},\n span_data: #{span_data.inspect}"
        txname = @txn_manager.get(trace_span_id).nil?? "" : @txn_manager.get(trace_span_id)
        SolarWindsAPM.logger.debug "######## txname #{txname} ########"
        evt.addInfo("TransactionName", txname)
        @txn_manager.del(trace_span_id)
      end

      def report_exception_event(span_event)
        evt = @context.createEvent((span_event.timestamp.to_i / 1000).to_i)
        evt.addInfo('Label', 'error')
        evt.addInfo('Spec', 'error')

        unless span_event.attributes.nil?
          evt.addInfo('ErrorClass', span_event.attributes['exception.type'])
          evt.addInfo('ErrorMsg', span_event.attributes['exception.message'])
          evt.addInfo('Backtrace', span_event.attributes['exception.stacktrace'])
          span_event.attributes.each do |key, value|
            evt.addInfo(key, value) unless ['exception.type', 'exception.message','exception.stacktrace'].include? key
          end
        end
        SolarWindsAPM.logger.debug "######## exception event #{evt.metadataString} ########"
        @reporter.send_report(evt, with_system_timestamp: false)
      end

      def report_info_event(span_event)
        evt = @context.createEvent((span_event.timestamp.to_i / 1000).to_i)
        evt.addInfo('Label', 'info')
        span_event.attributes&.each do |key, value|
          evt.addInfo(key, value)
        end
        SolarWindsAPM.logger.debug "######## info event #{evt.metadataString} ########"
        @reporter.send_report(evt, with_system_timestamp: false)
      end

      def build_meta_data(span_data, parent: false)
        flag = span_data.trace_flags.sampled?? 1 : 0
        version = "00"
        xtr = parent == false ? "#{version}-#{span_data.hex_trace_id}-#{span_data.hex_span_id}-0#{flag}" : "#{version}-#{span_data.hex_trace_id}-#{span_data.hex_parent_span_id}-0#{flag}"
        @metadata.fromString(xtr)
      end
    end
  end
end
