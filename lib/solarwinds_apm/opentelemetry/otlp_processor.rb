# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  module OpenTelemetry
    # reference: OpenTelemetry::SDK::Trace::SpanProcessor
    class OTLPProcessor
      HTTP_METHOD      = "http.method".freeze
      HTTP_ROUTE       = "http.route".freeze
      HTTP_STATUS_CODE = "http.status_code".freeze
      HTTP_URL         = "http.url".freeze
      LIBOBOE_HTTP_SPAN_STATUS_UNAVAILABLE = 0

      attr_reader :txn_manager
      attr_accessor :description

      # @param [Meter] meter the meteer created by ::OpenTelemetry.meter_provider.meter('meter_name')
      # @param [TxnNameManager] txn_manager storage for transaction name
      # @exporter [SolarWindsExporter] exporter SolarWindsExporter::OpenTelemetry::SolarWindsExporter
      def initialize(meter, txn_manager, exporter)
        @meter       = meter
        @txn_manager = txn_manager
        @exporter    = exporter
        @histogram   = nil
        @description = nil
      end

      # Called when a {Span} is started, if the {Span#recording?}
      # returns true.
      #
      # This method is called synchronously on the execution thread, should
      # not throw or block the execution thread.
      #
      # @param [Span] span the {Span} that just started.
      # @param [Context] parent_context the 
      #  started span.
      def on_start(span, parent_context)
        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] processor on_start span: #{span.inspect}, parent_context: #{parent_context.inspect}"}

        parent_span = ::OpenTelemetry::Trace.current_span(parent_context)
        return if parent_span && parent_span.context != ::OpenTelemetry::Trace::SpanContext::INVALID && parent_span.context.remote? == false

        trace_flags = span.context.trace_flags.sampled? ? '01' : '00'
        @txn_manager.set_root_context_h(span.context.hex_trace_id,"#{span.context.hex_span_id}-#{trace_flags}")

        @histogram = @meter.create_histogram('histogram', unit: 'smidgen', description: @description || '') if @histogram.nil?
      rescue StandardError => e
        SolarWindsAPM.logger.info {"[#{self.class}/#{__method__}] processor on_start error: #{e.message}"}
      end

      # Called when a {Span} is ended, if the {Span#recording?}
      # returns true.
      #
      # This method is called synchronously on the execution thread, should
      # not throw or block the execution thread.
      # Only calculate inbound metrics for service root spans
      #
      # @param [Span] span the {Span} that just ended.
      def on_finish(span)
        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] processor on_finish span: #{span.inspect}"}

        if span.parent_span_id != ::OpenTelemetry::Trace::INVALID_SPAN_ID 
          @exporter&.export([span.to_span_data]) if span.context.trace_flags.sampled?
          return
        end

        meter_attrs = {'sw.service_name' => ENV['OTEL_SERVICE_NAME'], 'sw.nonce' => rand(2**64) >> 1}

        span_time  = calculate_span_time(start_time: span.start_timestamp, end_time: span.end_timestamp)
        has_error  = error?(span)
        meter_attrs['sw.is_error'] = has_error ? 'true' : 'false'
        
        trans_name = calculate_transaction_names(span)

        if span_http?(span)
          status_code    = get_http_status_code(span)
          request_method = span.attributes[HTTP_METHOD]

          meter_attrs.merge!({'http.status_code' => status_code, 'http.method' => request_method, 'sw.transaction' => trans_name})
        else
          meter_attrs.merge!({'sw.transaction' => trans_name})
        end

        @histogram.record(span_time, attributes: meter_attrs)

        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] trans_name: #{trans_name}"}
        @txn_manager["#{span.context.hex_trace_id}-#{span.context.hex_span_id}"] = trans_name if span.context.trace_flags.sampled?
        @txn_manager.delete_root_context_h(span.context.hex_trace_id)
        @exporter&.export([span.to_span_data]) if span.context.trace_flags.sampled?

        ::OpenTelemetry.meter_provider.metric_readers.each(&:pull)
      rescue StandardError => e
        SolarWindsAPM.logger.info {"[#{self.class}/#{__method__}] can't flush span to exporter; processor on_finish error: #{e.message}"}
        ::OpenTelemetry::SDK::Trace::Export::FAILURE
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
        @exporter&.force_flush(timeout: timeout) || ::OpenTelemetry::SDK::Trace::Export::SUCCESS
      end

      # Called when {TracerProvider#shutdown} is called.
      #
      # @param [optional Numeric] timeout An optional timeout in seconds.
      # @return [Integer] Export::SUCCESS if no error occurred, Export::FAILURE if
      #   a non-specific failure occurred, Export::TIMEOUT if a timeout occurred.
      def shutdown(timeout: nil)
        @exporter&.shutdown(timeout: timeout) || ::OpenTelemetry::SDK::Trace::Export::SUCCESS
      end

      private

      # This span from inbound HTTP request if from a SERVER by some http.method
      def span_http?(span)
        (span.kind == ::OpenTelemetry::Trace::SpanKind::SERVER && !span.attributes[HTTP_METHOD].nil?)
      end

      # Calculate if this span instance has_error
      # return [Integer]
      def error?(span)
        span.status.code == ::OpenTelemetry::Trace::Status::ERROR ? 1 : 0
      end

      # Calculate HTTP status_code from span or default to UNAVAILABLE
      # Something went wrong in OTel or instrumented service crashed early
      # if no status_code in attributes of HTTP span
      def get_http_status_code(span)
        span.attributes[HTTP_STATUS_CODE] || LIBOBOE_HTTP_SPAN_STATUS_UNAVAILABLE
      end

      # Get trans_name and url_tran of this span instance.
      def calculate_transaction_names(span)
        trace_span_id = "#{span.context.hex_trace_id}-#{span.context.hex_span_id}"
        trans_name = @txn_manager.get(trace_span_id)
        if trans_name
          SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] found trans name from txn_manager: #{trans_name} by #{trace_span_id}"}
          @txn_manager.del(trace_span_id)
        else
          trans_name = span.attributes[HTTP_ROUTE] || nil
          trans_name = span.name if span.name && (trans_name.nil? || trans_name.empty?)
        end
        trans_name
      end

      # Calculate span time in microseconds (us) using start and end time
      # in nanoseconds (ns). OTel span start/end_time are optional.
      def calculate_span_time(start_time: nil, end_time: nil)
        return 0 if start_time.nil? || end_time.nil?

        ((end_time.to_i - start_time.to_i) / 1e3).round
      end
    end
  end
end