module SolarWindsOTelAPM
  module OpenTelemetry
    
    # reference: OpenTelemetry::SDK::Trace::SpanProcessor
    class SolarWindsProcessor


      HTTP_METHOD = "http.method"
      HTTP_ROUTE = "http.route"
      HTTP_STATUS_CODE = "http.status_code"
      HTTP_URL = "http.url"
      LIBOBOE_HTTP_SPAN_STATUS_UNAVAILABLE = 0

      def initialize(exporter, txn_manager)
        @exporter = exporter
        @txn_manager = txn_manager
      end

      # Called when a {Span} is started, if the {Span#recording?}
      # returns true.
      #
      # This method is called synchronously on the execution thread, should
      # not throw or block the execution thread.
      #
      # @param [Span] span the {Span} that just started.
      # @param [Context] parent_context the parent {Context} of the newly
      #  started span.
      def on_start(span, parent_context); end

      # Called when a {Span} is ended, if the {Span#recording?}
      # returns true.
      #
      # This method is called synchronously on the execution thread, should
      # not throw or block the execution thread.
      # Only calculate inbound metrics for service root spans
      #
      # @param [Span] span the {Span} that just ended.
      def on_finish(span) 

        if span.parent_span_id != ::OpenTelemetry::Trace::INVALID_SPAN_ID 
          @exporter&.export([span.to_span_data]) if span.context.trace_flags.sampled?
          return
        end

        http_span = is_span_http(span)
        span_time = calculate_span_time(span.start_timestamp, span.end_timestamp)

        domain = nil
        has_error = has_error(span)
        trans_name, url_tran = calculate_transaction_names(span)

        liboboe_txn_name = nil
        if http_span
          status_code = get_http_status_code(span)
          request_method = span.attributes["#{}"]

          SolarWindsOTelAPM.logger.debug "####### createHttpSpan with\n
                                          trans_name: #{trans_name}\n
                                          url_tran: #{url_tran}\n
                                          domain: #{domain}\n
                                          span_time: #{span_time}\n
                                          status_code: #{status_code}\n
                                          request_method: #{request_method}\n
                                          has_error: #{has_error}"

          liboboe_txn_name = SolarWindsOTelAPM::Span.createHttpSpan(trans_name,url_tran,domain,span_time,status_code,
                                                                                                request_method,has_error)
  
        else
          
          SolarWindsOTelAPM.logger.debug "####### createSpan with \n
                                          trans_name: #{trans_name}\n
                                          domain: #{domain}\n
                                          span_time: #{span_time}\n
                                          has_error: #{has_error}"

          liboboe_txn_name = SolarWindsOTelAPM::Span.createSpan(trans_name, domain, span_time, has_error)
        end

        SolarWindsOTelAPM.logger.debug "####### liboboe_txn_name: #{liboboe_txn_name}"
        @txn_manager["#{span.context.hex_trace_id}-#{span.context.hex_span_id}"] = liboboe_txn_name if span.context.trace_flags.sampled?

        @exporter&.export([span.to_span_data]) if span.context.trace_flags.sampled?
      end

      # Export all ended spans to the configured `Exporter` that have not yet
      # been exported.
      #
      # This method should only be called in cases where it is absolutely
      # necessary, such as when using some FaaS providers that may suspend
      # the process after an invocation, but before the `Processor` exports
      # the completed spans.
      #
      # @param [optional Numeric] timeout An optional timeout in seconds.
      # @return [Integer] Export::SUCCESS if no error occurred, Export::FAILURE if
      #   a non-specific failure occurred, Export::TIMEOUT if a timeout occurred.
      def force_flush(timeout: nil)
        @exporter&.force_flush(timeout: timeout) || ::OpenTelemetry::SDK::Metrics::Export::SUCCESS
      end

      # Called when {TracerProvider#shutdown} is called.
      #
      # @param [optional Numeric] timeout An optional timeout in seconds.
      # @return [Integer] Export::SUCCESS if no error occurred, Export::FAILURE if
      #   a non-specific failure occurred, Export::TIMEOUT if a timeout occurred.
      def shutdown(timeout: nil)
        @exporter&.shutdown(timeout: timeout) || ::OpenTelemetry::SDK::Metrics::Export::SUCCESS
      end

      private

      # This span from inbound HTTP request if from a SERVER by some http.method
      def is_span_http span
        SolarWindsOTelAPM.logger.debug "######## span.kind #{span.kind}  span.attributes: #{span.attributes[HTTP_METHOD]}"
        (span.kind == ::OpenTelemetry::Trace::SpanKind::SERVER && !span.attributes[HTTP_METHOD].nil?)
      end

      # Calculate if this span instance has_error
      # return [Integer]
      def has_error span
        (span.status.code == ::OpenTelemetry::Trace::Status::ERROR)? 1 : 0
      end

      # Calculate HTTP status_code from span or default to UNAVAILABLE
      # Something went wrong in OTel or instrumented service crashed early
      # if no status_code in attributes of HTTP span
      def get_http_status_code span
        status_code = span.attributes["#{HTTP_STATUS_CODE}"]
        status_code = LIBOBOE_HTTP_SPAN_STATUS_UNAVAILABLE if status_code.nil?
        status_code
      end

      # Get trans_name and url_tran of this span instance.
      def calculate_transaction_names span
        trans_name = nil
        trans_name = span.attributes[HTTP_ROUTE] if span.attributes[HTTP_ROUTE]
        trans_name = span.name if span.name && (trans_name.nil? || trans_name.empty?)
        return trans_name, span.attributes[HTTP_URL]
      end

      # Calculate span time in microseconds (us) using start and end time
      # in nanoseconds (ns). OTel span start/end_time are optional.
      def calculate_span_time start_time=nil, end_time=nil
        return 0 if start_time.nil? || end_time.nil?
        return ((end_time.to_i - start_time.to_i) / 1e3).round
      end

    end
  end
end