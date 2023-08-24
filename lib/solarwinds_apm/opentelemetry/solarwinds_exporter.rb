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

        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] span_data: #{span_data.inspect}\n"}
        begin
          md = build_meta_data(span_data)
          event = nil
          if span_data.parent_span_id != ::OpenTelemetry::Trace::INVALID_SPAN_ID 
            parent_md = build_meta_data(span_data, parent: true)
            event = @context.createEntry(md, (span_data.start_timestamp.to_i / 1000).to_i, parent_md)
            SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] Continue trace from parent metadata: #{parent_md.toString}."}
          else
            event = @context.createEntry(md, (span_data.start_timestamp.to_i / 1000).to_i) 
            add_info_transaction_name(span_data, event)
            SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] Start a new trace."}
          end
          
          event.addInfo('Layer', span_data.name)
          event.addInfo('sw.span_kind', span_data.kind.to_s)
          event.addInfo('Language', 'Ruby')
          
          add_instrumentation_scope(event, span_data)
          add_instrumented_framework(event, span_data)
          add_span_data_attributes(event, span_data.attributes) if span_data.attributes

          event.addInfo(SolarWindsAPM::Constants::INTL_SWO_OTEL_STATUS, span_data.status.ok?? 'OK' : 'ERROR')
          event.addInfo(SolarWindsAPM::Constants::INTL_SWO_OTEL_STATUS_DESCRIPTION, span_data.status.description) unless span_data.status.description.empty?

          @reporter.send_report(event, with_system_timestamp: false)

          # info / exception event
          span_data.events&.each do |span_data_event|
            span_data_event.name == 'exception' ? report_exception_event(span_data_event) : report_info_event(span_data_event)
          end

          event = @context.createExit((span_data.end_timestamp.to_i / 1000).to_i)
          event.addInfo('Layer', span_data.name)
          @reporter.send_report(event, with_system_timestamp: false)
          SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] Exit a trace: #{event.metadataString}"}
        rescue StandardError => e
          SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] \n #{e.message} #{e.backtrace}\n"}
          raise
        end
      end

      ##
      # extract the span_data.attributes (OpenTelemetry::SDK::Trace::SpanData.attributes)
      def add_span_data_attributes(event, span_attributes)
        target     = 'http.target'
        attributes = span_attributes.dup
        attributes[target] = attributes[target].split('?').first if attributes[target] && SolarWindsAPM::Config[:log_args] == false # remove url parameters
        attributes.each { |k, v| event.addInfo(k, v) }
        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] span_data attributes added: #{attributes.inspect}"}
      end

      ##
      # get instrumentation scope data: scope name and version.
      # the version if the opentelemetry-instrumentation-* gem version
      def add_instrumentation_scope(event, span_data)
        scope_name = ""
        scope_version = ""
        if span_data.instrumentation_scope
          scope_name = span_data.instrumentation_scope.name if span_data.instrumentation_scope.name
          scope_version = span_data.instrumentation_scope.version if span_data.instrumentation_scope.version
        end
        event.addInfo(SolarWindsAPM::Constants::INTL_SWO_OTEL_SCOPE_NAME, scope_name) 
        event.addInfo(SolarWindsAPM::Constants::INTL_SWO_OTEL_SCOPE_VERSION, scope_version)        
      end

      ##
      # add the gem library version to event
      # p.s. gem library version is not same as the opentelemetry-instrumentation-* gem version
      def add_instrumented_framework(event, span_data)
        scope_name = span_data.instrumentation_scope.name
        scope_name = scope_name.downcase if scope_name
        return unless scope_name&.include? "opentelemetry::instrumentation"
          
        framework = scope_name.split("::")[2..]&.join("::")
        return if framework.nil? || framework.empty?
        
        framework         = normalize_framework_name(framework)
        framework_version = check_framework_version(framework)
        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] #{span_data.instrumentation_scope.name} with #{framework} and version #{framework_version}"}
        event.addInfo("Ruby.#{framework}.Version",framework_version) unless framework_version.nil?
      end

      ##
      # helper function that extract gem library version for func add_instrumented_framework
      def check_framework_version(framework)
        framework_version = nil
        if @version_cache.keys.include? framework

          framework_version = @version_cache[framework]
        else

          begin
            require framework
            framework_version = Gem.loaded_specs[framework].version.to_s
          rescue LoadError => e
            SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] couldn't load #{framework} with error #{e.message}; skip"}
          rescue StandardError => e
            SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] couldn't find #{framework} with error #{e.message}; skip"}
          ensure
            @version_cache[framework] = framework_version
          end
        end
        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] current framework version cached: #{@version_cache.inspect}"}
        framework_version
      end

      ##
      # helper function that convert opentelemetry instrumentation name to gem library understandable
      def normalize_framework_name(framework)
        case framework
        when "net::http"
          normalized = "net/http"
        else
          normalized = framework
        end
        normalized
      end

      ##
      # Add transaction name from cache to root span then removes from cache
      def add_info_transaction_name(span_data, event)
        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] transaction manager: #{@txn_manager.inspect}."}
        trace_span_id = "#{span_data.hex_trace_id}-#{span_data.hex_span_id}"
        txname = @txn_manager.get(trace_span_id) || ''
        event.addInfo("TransactionName", txname)
        @txn_manager.del(trace_span_id)
      end

      ##
      # report exception event
      def report_exception_event(span_event)
        event = @context.createEvent((span_event.timestamp.to_i / 1000).to_i)
        event.addInfo('Label', 'error')
        event.addInfo('Spec', 'error')

        unless span_event.attributes.nil?
          attributes = span_event.attributes.dup
          attributes.delete('exception.type') if event.addInfo('ErrorClass', attributes['exception.type'])
          attributes.delete('exception.message') if event.addInfo('ErrorMsg', attributes['exception.message'])
          attributes.delete('exception.stacktrace') if event.addInfo('Backtrace', attributes['exception.stacktrace'])
          attributes.map { |key, value| event.addInfo(key, value) }
        end

        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] exception event #{event.metadataString}"}
        @reporter.send_report(event, with_system_timestamp: false)
      end

      ##
      # report non-exception/info event
      def report_info_event(span_event)
        event = @context.createEvent((span_event.timestamp.to_i / 1000).to_i)
        event.addInfo('Label', 'info')
        span_event.attributes.map { |key, value| event.addInfo(key, value) }if span_event.attributes
        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] info event #{event.metadataString}"}
        @reporter.send_report(event, with_system_timestamp: false)
      end

      def build_meta_data(span_data, parent: false)
        flag = span_data.trace_flags.sampled?? 1 : 0
        xtr = parent == false ? "00-#{span_data.hex_trace_id}-#{span_data.hex_span_id}-0#{flag}" : "00-#{span_data.hex_trace_id}-#{span_data.hex_parent_span_id}-0#{flag}"
        @metadata.fromString(xtr)
      end
    end
  end
end
