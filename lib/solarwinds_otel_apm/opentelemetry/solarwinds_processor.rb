module SolarWindsOTelAPM
  module OpenTelemetry
    class SolarWindsProcessor


      HTTP_METHOD = "http.method"
      HTTP_ROUTE = "http.route"
      HTTP_STATUS_CODE = "http.status_code"
      HTTP_URL = "http.url"

      LIBOBOE_HTTP_SPAN_STATUS_UNAVAILABLE = 0

      # def __init__(
      #     self,
      #     apm_txname_manager: "SolarWindsTxnNameManager",
      #     agent_enabled: bool,
      # ) -> None:
      #     self._apm_txname_manager = apm_txname_manager
      #     if agent_enabled:
      #         from solarwinds_apm.extension.oboe import Span
      #         self._span = Span
      #     else:
      #         from solarwinds_apm.apm_noop import Span
      #         self._span = Span

      def initialize(exporter, txn_manager, agent_enabled)
        @exporter = exporter
        @txn_manager = txn_manager
        @agent_enabled = agent_enabled
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
      #
      # @param [Span] span the {Span} that just ended.
      def on_finish(span) 

        parent_span_context = span.parent
        return if !parent_span_context.nil? && parent_span_context.valid? and !parent_span_context.remote?

        is_span_http = is_span_http(span)
        span_time    = calculate_span_time(span.start_timestamp, span.end_timestamp)

        # TODO Use `domain` for custom transaction naming after alpha/beta
        domain = nil
        has_error = has_error(span)
        trans_name, url_tran = calculate_transaction_names(span)

        liboboe_txn_name = None
        if is_span_http
          
          status_code = get_http_status_code(span)
          request_method = span.attributes["#{HTTP_METHOD}"]

          SolarWindsOTelAPM::Logger.debug "createHttpSpan with trans_name: #{trans_name}, url_tran: #{url_tran}, domain: #{domain}, 
                                              span_time: #{span_time}, status_code: #{status_code}, request_method: #{request_method},
                                              has_error: #{has_error}"
          liboboe_txn_name = SolarWindsOTelAPM::Span.createHttpSpan(trans_name,url_tran,domain,
                                                                    span_time,status_code,request_method,has_error)
  
        else
          SolarWindsOTelAPM::Logger.debug "createHttpSpan with trans_name: #{trans_name}, domain: #{domain}, 
                                              span_time: #{span_time}, has_error: #{has_error}"
          liboboe_txn_name = SolarWindsOTelAPM::Span.createHttpSpan(trans_name, domain, span_time, has_error)
        end

        @txn_manager["#{span.hex_trace_id}-#{span.hex_span_id}"] = liboboe_txn_name if span.trace_flags.sampled?
        
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
        Export::SUCCESS
      end

      # Called when {TracerProvider#shutdown} is called.
      #
      # @param [optional Numeric] timeout An optional timeout in seconds.
      # @return [Integer] Export::SUCCESS if no error occurred, Export::FAILURE if
      #   a non-specific failure occurred, Export::TIMEOUT if a timeout occurred.
      def shutdown(timeout: nil)
        Export::SUCCESS
      end


      private


      # This span from inbound HTTP request if from a SERVER by some http.method
      def is_span_http span
        return (span.kind == ::OpenTelemetry::Trace::SpanKind::SERVER && !span.attributes["#{HTTP_METHOD}"].nil?)

      # Calculate if this span instance has_error
      def has_error span
        return (span.status.code == ::OpenTelemetry::Trace::Status::ERROR)

      # Calculate HTTP status_code from span or default to UNAVAILABLE
      # Something went wrong in OTel or instrumented service crashed early
      # if no status_code in attributes of HTTP span
      def get_http_status_code span
        status_code = span.attributes["#{HTTP_STATUS_CODE}"]
        status_code = LIBOBOE_HTTP_SPAN_STATUS_UNAVAILABLE if status_code.nil?
        status_code

      # Get trans_name and url_tran of this span instance.
      def calculate_transaction_names span
        trans_name = nil
        trans_name = span.attributes["#{HTTP_ROUTE}"] if span.attributes["#{HTTP_ROUTE}"]
        trans_name = span.name if span.name && (trans_name.nil? || trans_name.empty?)
        return trans_name, span.attributes["#{HTTP_URL}"]

      # Calculate span time in microseconds (us) using start and end time
      # in nanoseconds (ns). OTel span start/end_time are optional.
      def calculate_span_time start_time=nil, end_time=nil)
        if start_time.nil? || end_time.nil?
          return 0
        return ((end_time.to_i - start_time.to_i) / 1e3).round

    end
  end
end