# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  module OpenTelemetry
    # reference: OpenTelemetry::SDK::Trace::SpanProcessor
    class SolarWindsProcessor
      HTTP_METHOD      = 'http.method'
      HTTP_ROUTE       = 'http.route'
      HTTP_STATUS_CODE = 'http.status_code'
      HTTP_URL         = 'http.url'
      LIBOBOE_HTTP_SPAN_STATUS_UNAVAILABLE = 0

      attr_reader :txn_manager

      def initialize(exporter, txn_manager)
        @exporter = exporter
        @txn_manager = txn_manager
      end

      # Called when a {Span} is started, if the {Span#recording?}
      # returns true.
      #
      # @param [Span] span the {Span} that just started.
      # @param [Context] parent_context the parent {Context} of the newly
      #  started span.
      def on_start(span, parent_context)
        SolarWindsAPM.logger.debug do
          "[#{self.class}/#{__method__}] processor on_start span: #{span.inspect}, parent_context: #{parent_context.inspect}"
        end

        parent_span = ::OpenTelemetry::Trace.current_span(parent_context)
        return if parent_span && parent_span.context != ::OpenTelemetry::Trace::SpanContext::INVALID && parent_span.context.remote? == false

        trace_flags = span.context.trace_flags.sampled? ? '01' : '00'
        @txn_manager.set_root_context_h(span.context.hex_trace_id, "#{span.context.hex_span_id}-#{trace_flags}")
      rescue StandardError => e
        SolarWindsAPM.logger.info { "[#{self.class}/#{__method__}] processor on_start error: #{e.message}" }
      end

      # Called when a {Span} is ended, if the {Span#recording?}
      # returns true.
      #
      # @param [Span] span the {Span} that just ended.
      def on_finish(span)
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] processor on_finish span: #{span.inspect}" }

        if span.parent_span_id != ::OpenTelemetry::Trace::INVALID_SPAN_ID
          @exporter&.export([span.to_span_data]) if span.context.trace_flags.sampled?
          return
        end

        span_time  = calculate_span_time(start_time: span.start_timestamp, end_time: span.end_timestamp)
        domain     = nil
        has_error  = error?(span)
        trans_name = calculate_transaction_names(span)
        if span_http?(span)
          status_code    = get_http_status_code(span)
          request_method = span.attributes[HTTP_METHOD]
          url_tran       = span.attributes[HTTP_URL]

          SolarWindsAPM.logger.debug do
            "[#{self.class}/#{__method__}] createHttpSpan with\n
                                          trans_name: #{trans_name}\n
                                          url_tran: #{url_tran}\n
                                          domain: #{domain}\n
                                          span_time: #{span_time}\n
                                          status_code: #{status_code}\n
                                          request_method: #{request_method}\n
                                          has_error: #{has_error}"
          end

          liboboe_txn_name = SolarWindsAPM::Span.createHttpSpan(trans_name, url_tran, domain, span_time, status_code,
                                                                request_method, has_error)

        else

          SolarWindsAPM.logger.debug do
            "[#{self.class}/#{__method__}] createSpan with \n
                                          trans_name: #{trans_name}\n
                                          domain: #{domain}\n
                                          span_time: #{span_time}\n
                                          has_error: #{has_error}"
          end

          liboboe_txn_name = SolarWindsAPM::Span.createSpan(trans_name, domain, span_time, has_error)
        end

        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] liboboe_txn_name: #{liboboe_txn_name}" }
        if span.context.trace_flags.sampled?
          @txn_manager["#{span.context.hex_trace_id}-#{span.context.hex_span_id}"] =
            liboboe_txn_name
        end
        @txn_manager.delete_root_context_h(span.context.hex_trace_id)
        @exporter&.export([span.to_span_data]) if span.context.trace_flags.sampled?
      rescue StandardError => e
        SolarWindsAPM.logger.info do
          "[#{self.class}/#{__method__}] can't flush span to exporter; processor on_finish error: #{e.message}"
        end
        ::OpenTelemetry::SDK::Trace::Export::FAILURE
      end

      # Export all ended spans to the configured `Exporter` that have not yet
      # been exported.
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
        span.kind == ::OpenTelemetry::Trace::SpanKind::SERVER && !span.attributes[HTTP_METHOD].nil?
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
      # Predecessor order: custom SDK > env var SW_APM_TRANSACTION_NAME > automatic naming
      def calculate_transaction_names(span)
        trace_span_id = "#{span.context.hex_trace_id}-#{span.context.hex_span_id}"
        trans_name = @txn_manager.get(trace_span_id)
        if trans_name
          SolarWindsAPM.logger.debug do
            "[#{self.class}/#{__method__}] found trans name from txn_manager: #{trans_name} by #{trace_span_id}"
          end
          @txn_manager.del(trace_span_id)
        elsif ENV.key?('SW_APM_TRANSACTION_NAME') && ENV['SW_APM_TRANSACTION_NAME'] != ''
          trans_name = ENV.fetch('SW_APM_TRANSACTION_NAME', nil)
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
