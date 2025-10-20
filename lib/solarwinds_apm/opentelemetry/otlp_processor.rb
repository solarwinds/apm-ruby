# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  module OpenTelemetry
    # reference: OpenTelemetry::SDK::Trace::SpanProcessor
    class OTLPProcessor
      attr_reader :txn_manager

      SW_TRANSACTION_NAME = 'sw.transaction'
      SW_IS_ENTRY_SPAN    = 'sw.is_entry_span'
      SW_IS_ERROR         = 'sw.is_error'

      HTTP_METHOD         = 'http.method'
      HTTP_ROUTE          = 'http.route'
      HTTP_STATUS_CODE    = 'http.status_code'
      HTTP_URL            = 'http.url'

      HTTP_RESPONSE_STATUS_CODE = 'http.response.status_code'
      HTTP_REQUEST_METHOD = 'http.request.method'

      INVALID_HTTP_STATUS_CODE = 0

      def initialize(txn_manager)
        @txn_manager = txn_manager
        @metrics     = init_response_time_metrics
        @is_lambda   = SolarWindsAPM::Utils.determine_lambda
        @transaction_name = nil
      end

      # @param [Span] span the (mutable) {Span} that just started.
      # @param [Context] parent_context of the started span.
      def on_start(span, parent_context)
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] processor on_start span: #{span.to_span_data.inspect}" }

        return if non_entry_span(parent_context: parent_context)

        trace_flags = span.context.trace_flags.sampled? ? '01' : '00'
        @txn_manager&.set_root_context_h(span.context.hex_trace_id, "#{span.context.hex_span_id}-#{trace_flags}")
        span.add_attributes({ SW_IS_ENTRY_SPAN => true })
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] processor on_start end" }
      rescue StandardError => e
        SolarWindsAPM.logger.info { "[#{self.class}/#{__method__}] processor on_start error: #{e.message}" }
      end

      def on_finishing(span)
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] processor on_finishing span attributes: #{span.attributes}" }
        return if non_entry_span(span: span)

        @transaction_name = calculate_transaction_names(span)
        span.set_attribute(SW_TRANSACTION_NAME, @transaction_name)
        @txn_manager.delete_root_context_h(span.context.hex_trace_id)
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] processor on_finishing end" }
      end

      # @param [Span] span the (immutable) {Span} that just ended.
      def on_finish(span)
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] processor on_finish span attributes: #{span.attributes}" }
        return if non_entry_span(span: span)

        record_request_metrics(span)

        # pull should work on any instrument from oboe_sampler
        ::OpenTelemetry.meter_provider.metric_readers.each do |reader|
          reader.pull if reader.respond_to? :pull
        end
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] processor on_finish end" }
      rescue StandardError => e
        SolarWindsAPM.logger.info { "[#{self.class}/#{__method__}] processor on_finish error: #{e.message}" }
      end

      # @param [optional Numeric] timeout An optional timeout in seconds.
      # @return [Integer] Export::SUCCESS if no error occurred, Export::FAILURE if
      #   a non-specific failure occurred, Export::TIMEOUT if a timeout occurred.
      def force_flush(timeout: nil) # rubocop:disable Lint/UnusedMethodArgument
        ::OpenTelemetry::SDK::Trace::Export::SUCCESS
      end

      # @param [optional Numeric] timeout An optional timeout in seconds.
      # @return [Integer] Export::SUCCESS if no error occurred, Export::FAILURE if
      #   a non-specific failure occurred, Export::TIMEOUT if a timeout occurred.
      def shutdown(timeout: nil) # rubocop:disable Lint/UnusedMethodArgument
        ::OpenTelemetry::SDK::Trace::Export::SUCCESS
      end

      private

      def init_response_time_metrics
        # add the ExponentialBucketHistogram view
        if defined? ::OpenTelemetry::Exporter::OTLP::Metrics && Gem::Version.new(::OpenTelemetry::Exporter::OTLP::Metrics::VERSION) >= Gem::Version.new('0.5.0')
          ::OpenTelemetry.meter_provider.add_view('trace.service.response_time',
                                                  aggregation: ::OpenTelemetry::SDK::Metrics::Aggregation::ExponentialBucketHistogram.new(aggregation_temporality: :delta),
                                                  type: :histogram,
                                                  unit: 'ms')
        end

        meter = ::OpenTelemetry.meter_provider.meter('sw.apm.request.metrics')
        instrument = meter.create_histogram('trace.service.response_time', unit: 'ms', description: 'Duration of each entry span for the service, typically meaning the time taken to process an inbound request.')
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] Adding ExponentialBucketHistogram for response time metrics: #{instrument.inspect}" }
        { response_time: instrument }
      end

      def meter_attributes(span)
        meter_attrs = {
          SW_IS_ERROR => error?(span) == 1,
          SW_TRANSACTION_NAME => @transaction_name
        }

        is_http_span = span_http?(span)

        if is_http_span
          http_status_code = get_http_status_code(span)
          meter_attrs[HTTP_STATUS_CODE] = http_status_code if http_status_code != 0
          meter_attrs[HTTP_METHOD] = span.attributes[HTTP_METHOD] if span.attributes[HTTP_METHOD]
          meter_attrs[HTTP_METHOD] = span.attributes[HTTP_REQUEST_METHOD] if span.attributes[HTTP_REQUEST_METHOD]
        end

        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] is_http_span: #{is_http_span}; meter_attrs: #{meter_attrs.inspect}" }
        meter_attrs.compact!
        meter_attrs
      end

      def calculate_lambda_transaction_name(span_name)
        txn_name = (ENV['SW_APM_TRANSACTION_NAME'] || ENV['AWS_LAMBDA_FUNCTION_NAME'] || span_name || 'unknown').slice(0, SolarWindsAPM::Constants::MAX_TXN_NAME_LENGTH)
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] Lambda transaction name: #{txn_name} (from env_txn=#{ENV.fetch('SW_APM_TRANSACTION_NAME', nil)}, lambda_func=#{ENV.fetch('AWS_LAMBDA_FUNCTION_NAME', nil)}, span_name=#{span_name})" }
        txn_name
      end

      # Get trans_name and url_tran of this span instance.
      # Predecessor order: custom SDK > env var SW_APM_TRANSACTION_NAME > automatic naming
      def calculate_transaction_names(span)
        return calculate_lambda_transaction_name(span.name) if @is_lambda

        trace_span_id = "#{span.context.hex_trace_id}-#{span.context.hex_span_id}"
        trans_name = @txn_manager.get(trace_span_id)
        if trans_name
          SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] Using transaction name from txn_manager: #{trans_name} (#{trace_span_id})" }
          @txn_manager.del(trace_span_id)
        elsif !ENV['SW_APM_TRANSACTION_NAME'].to_s.empty?
          trans_name = ENV.fetch('SW_APM_TRANSACTION_NAME', nil)
          SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] Using transaction name from env var: #{trans_name}" }
        else
          trans_name = span.attributes[HTTP_ROUTE]
          trans_name = span.name if trans_name.to_s.empty?
          SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] Using transaction name from span.attributes: #{span.attributes[HTTP_ROUTE]} or span.name: #{span.name}" }
        end
        trans_name.to_s.slice(0, SolarWindsAPM::Constants::MAX_TXN_NAME_LENGTH)
      end

      def record_request_metrics(span)
        meter_attrs = meter_attributes(span)
        span_time = calculate_span_time(start_time: span.start_timestamp, end_time: span.end_timestamp)
        span_time = (span_time / 1e3).round
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] entry span, response_time: #{span_time}." }
        @metrics[:response_time].record(span_time, attributes: meter_attrs)
      end

      # Calculate span time in microseconds (us) using start and end time
      # in nanoseconds (ns). OTel span start/end_time are optional.
      def calculate_span_time(start_time: nil, end_time: nil)
        return 0 if start_time.nil? || end_time.nil?

        ((end_time.to_i - start_time.to_i) / 1e3).round
      end

      # Calculate if this span instance has_error
      # return [Integer]
      def error?(span)
        span.status.code == ::OpenTelemetry::Trace::Status::ERROR ? 1 : 0
      end

      # This span from inbound HTTP request if from a SERVER by some http.method
      def span_http?(span)
        (!span.attributes[HTTP_METHOD].nil? || !span.attributes[HTTP_REQUEST_METHOD].nil?) && span.kind == ::OpenTelemetry::Trace::SpanKind::SERVER
      end

      # Calculate HTTP status_code from span or default to UNAVAILABLE
      # Something went wrong in OTel or instrumented service crashed early
      # if no status_code in attributes of HTTP span
      def get_http_status_code(span)
        span.attributes[HTTP_RESPONSE_STATUS_CODE] || span.attributes[HTTP_STATUS_CODE] || INVALID_HTTP_STATUS_CODE
      end

      # check if it's entry span based on no parent or parent is remote
      def non_entry_span(span: nil, parent_context: nil)
        if parent_context
          parent_span = ::OpenTelemetry::Trace.current_span(parent_context)
          parent_span && parent_span.context != ::OpenTelemetry::Trace::SpanContext::INVALID && parent_span.context.remote? == false
        elsif span
          span.attributes['sw.is_entry_span'] != true
        end
      end
    end
  end
end
