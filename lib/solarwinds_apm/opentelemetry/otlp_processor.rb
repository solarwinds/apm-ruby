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

        parent_span = ::OpenTelemetry::Trace.current_span(parent_context)
        return if parent_span && parent_span.context != ::OpenTelemetry::Trace::SpanContext::INVALID && parent_span.context.remote? == false

        trace_flags = span.context.trace_flags.sampled? ? '01' : '00'
        @txn_manager.set_root_context_h(span.context.hex_trace_id,"#{span.context.hex_span_id}-#{trace_flags}")

        if @metrics.size == 0
          request_meter  = @meters['sw.apm.request.metrics']

          @metrics[:response_time] = request_meter.create_histogram('trace.service.response_time', unit: nil, description: nil || '')
          @metrics[:requests]      = request_meter.create_counter('trace.service.requests', unit: nil, description: nil || '')
          @metrics[:errors]        = request_meter.create_counter('trace.service.errors', unit: nil, description: nil || '')

          sampling_meter = @meters['sw.apm.sampling.metrics']
          
          @metrics[:tracecount]    = sampling_meter.create_counter('trace.service.tracecount', unit: nil, description: nil  || '')
          @metrics[:samplecount]   = sampling_meter.create_counter('trace.service.samplecount', unit: nil, description: nil  || '')
          @metrics[:request_count] = sampling_meter.create_counter('trace.service.request_count', unit: nil, description: nil  || '')
          @metrics[:toex_count]    = sampling_meter.create_counter('trace.service.tokenbucket_exhaustion_count', unit: nil, description: nil  || '')
          @metrics[:through_count] = sampling_meter.create_counter('trace.service.through_trace_count', unit: nil, description: nil  || '')
          @metrics[:tt_count]      = sampling_meter.create_counter('trace.service.triggered_trace_count', unit: nil, description: nil  || '')

          # use guage
          @metrics[:sample_rate]   = sampling_meter.create_counter('trace.service.sample_rate', unit: nil, description: nil  || '')
          @metrics[:sample_source] = sampling_meter.create_counter('trace.service.sample_source', unit: nil, description: nil  || '')
        end
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

        # metrics per trace, therefore, we only record the parent span (span.parent_span_id has to be 00000000000 INVALID_SPAN_ID to qualify as parent span)
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

        @metrics[:response_time].record(span_time, attributes: meter_attrs)
        @metrics[:requests].add(1, attributes: meter_attrs)

        meter_attrs.delete('sw.is_error')
        meter_attrs['sw.is_error'] ? @metrics[:errors].add(1, attributes: meter_attrs) : @metrics[:errors].add(0, attributes: meter_attrs)

        record_sampling_metrics

        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] trans_name: #{trans_name}"}
        @txn_manager["#{span.context.hex_trace_id}-#{span.context.hex_span_id}"] = trans_name if span.context.trace_flags.sampled?
        @txn_manager.delete_root_context_h(span.context.hex_trace_id)
        @exporter&.export([span.to_span_data]) if span.context.trace_flags.sampled?

        ::OpenTelemetry.meter_provider.metric_readers.each(&:pull)
      rescue StandardError => e
        SolarWindsAPM.logger.info {"[#{self.class}/#{__method__}] can't flush span to exporter; processor on_finish error: #{e.message}"}
        ::OpenTelemetry::SDK::Trace::Export::FAILURE
      end

      private

      # oboe_api will return 0 in case of failed operation, and report 0 value
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

        _, last_used_sample_rate   = SolarWindsAPM.oboe_api.getLastUsedSampleRate
        @metrics[:sample_rate].add(last_used_sample_rate)

        _, last_used_sample_source = SolarWindsAPM.oboe_api.getLastUsedSampleSource
        @metrics[:sample_source].add(last_used_sample_source)
      end
    end
  end
end