# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  module OpenTelemetry
    # reference: OpenTelemetry::SDK::Trace::SpanProcessor; inheritance: SolarWindsProcessor
    class OTLPProcessor < SolarWindsProcessor
      attr_accessor :description

      # @param [Hash] meters the hash of meter created by ::OpenTelemetry.meter_provider.meter('meter_name')
      # @param [TxnNameManager] txn_manager storage for transaction name
      # @exporter [Exporter] exporter reporter that send trace data
      def initialize(meters, exporter, txn_manager)
        super(exporter, txn_manager)
        @meters      = meters
        @metrics     = {}
        @description = {}
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

        initialize_metrics if @metrics.size == 0

        parent_span = ::OpenTelemetry::Trace.current_span(parent_context)
        return if parent_span && parent_span.context != ::OpenTelemetry::Trace::SpanContext::INVALID && parent_span.context.remote? == false

        span_attrs = span_attributes(span)
        span.add_attributes(span_attrs)

        trace_flags = span.context.trace_flags.sampled? ? '01' : '00'
        @txn_manager.set_root_context_h(span.context.hex_trace_id,"#{span.context.hex_span_id}-#{trace_flags}")
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
        # SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] processor on_finish span: #{span.inspect}"}

        # metrics per trace, therefore, we only record the parent span (span.parent_span_id has to be 00000000000 INVALID_SPAN_ID to qualify as parent span)
        if span.parent_span_id != ::OpenTelemetry::Trace::INVALID_SPAN_ID 
          return unless span.context.trace_flags.sampled?

          @exporter&.export([span.to_span_data])
          record_sampling_metrics
          ::OpenTelemetry.meter_provider.metric_readers.each(&:pull)
        end

        meter_attrs = meter_attributes(span)
        span_time   = calculate_span_time(start_time: span.start_timestamp, end_time: span.end_timestamp)

        @metrics[:response_time].record(span_time, attributes: meter_attrs)
        @exporter&.export([span.to_span_data]) if span.context.trace_flags.sampled?

        record_sampling_metrics
        ::OpenTelemetry.meter_provider.metric_readers.each(&:pull)
      rescue StandardError => e
        SolarWindsAPM.logger.info {"[#{self.class}/#{__method__}] can't flush span to exporter; processor on_finish error: #{e.message}"}
        ::OpenTelemetry::SDK::Trace::Export::FAILURE
      end

      private

      def span_attributes(span)
        span_attrs = {}
        trans_name = calculate_transaction_name_lambda(span)
        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] trans_name: #{trans_name}"}
        @txn_manager["#{span.context.hex_trace_id}-#{span.context.hex_span_id}"] = trans_name if span.context.trace_flags.sampled?
        @txn_manager.delete_root_context_h(span.context.hex_trace_id)

        span_attrs['sw.transaction']  = trans_name.slice(0,255)

        if span_http?(span)
          span_attrs['http.status_code'] = get_http_status_code(span)
          span_attrs['http.method'] = span.attributes[HTTP_METHOD]
        end
        span_attrs
      end

      def meter_attributes(span)
        meter_attrs = {}
        meter_attrs['sw.service_name'] = ENV['OTEL_SERVICE_NAME'] # Service name override tag. Only set if Service Name Override is set for this request.
        meter_attrs['sw.nonce']        = rand(2**64) >> 1
        meter_attrs['sw.is_error']     = error?(span) ? true : false

        if span_http?(span)
          meter_attrs['http.status_code'] = get_http_status_code(span)
          meter_attrs['http.method'] = span.attributes[HTTP_METHOD]
        end

        meter_attrs
      end

      # custom SDK > configured name (e.g. env var: SW_APM_TRANSACTION_NAME) > automatic naming (AWS_LAMBDA_FUNCTION_NAME) > "unknown"
      def calculate_transaction_name_lambda(span)
        trace_span_id = "#{span.context.hex_trace_id}-#{span.context.hex_span_id}"
        trans_name = @txn_manager.get(trace_span_id)
        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] possible transaction name: #{trans_name} from #{trace_span_id}"}
        @txn_manager.del(trace_span_id)
        trans_name || ENV['SW_APM_TRANSACTION_NAME'] || ENV['AWS_LAMBDA_FUNCTION_NAME'] || 'unknown'
      end

      def initialize_metrics
        request_meter  = @meters['sw.apm.request.metrics']

        @metrics[:response_time] = request_meter.create_histogram('trace.service.response_time', unit: 'milliseconds', description: nil || '')

        sampling_meter = @meters['sw.apm.sampling.metrics']

        @metrics[:tracecount]    = sampling_meter.create_counter('trace.service.tracecount', unit: nil, description: nil  || '')
        @metrics[:samplecount]   = sampling_meter.create_counter('trace.service.samplecount', unit: nil, description: nil  || '')
        @metrics[:request_count] = sampling_meter.create_counter('trace.service.request_count', unit: nil, description: nil  || '')
        @metrics[:toex_count]    = sampling_meter.create_counter('trace.service.tokenbucket_exhaustion_count', unit: nil, description: nil  || '')
        @metrics[:through_count] = sampling_meter.create_counter('trace.service.through_trace_count', unit: nil, description: nil  || '')
        @metrics[:tt_count]      = sampling_meter.create_counter('trace.service.triggered_trace_count', unit: nil, description: nil  || '')
      end

      # oboe_api will return 0 in case of failed operation, and report 0 value
      # sampling metrics is recorded for each span (include non-entry span)
      # metrics should be exported after sampling decision is made
      def record_sampling_metrics
        _, trace_count   = SolarWindsAPM.oboe_api.consumeTraceCount
        @metrics[:tracecount].add(trace_count)

        _, sample_count  = SolarWindsAPM.oboe_api.consumeSampleCount
        @metrics[:samplecount].add(sample_count)

        _, request_count = SolarWindsAPM.oboe_api.consumeRequestCount
        @metrics[:request_count].add(request_count)

        _, token_bucket_exhaustion_count = SolarWindsAPM.oboe_api.consumeTokenBucketExhaustionCount
        @metrics[:toex_count].add(token_bucket_exhaustion_count)

        _, through_trace_count     = SolarWindsAPM.oboe_api.consumeThroughTraceCount
        @metrics[:through_count].add(through_trace_count)

        _, triggered_trace_count   = SolarWindsAPM.oboe_api.consumeTriggeredTraceCount
        @metrics[:tt_count].add(triggered_trace_count)
      end
    end
  end
end
