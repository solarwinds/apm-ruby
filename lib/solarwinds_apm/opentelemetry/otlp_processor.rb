# frozen_string_literal: true

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

      def initialize
        super(nil)
        @meters  = init_meters
        @metrics = init_metrics
      end

      # @param [Span] span the {Span} that just started.
      # @param [Context] parent_context the
      #  started span.
      def on_start(span, parent_context)
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] processor on_start span: #{span.to_span_data.inspect}" }

        return if non_entry_span(parent_context: parent_context)

        span.add_attributes(span_attributes(span))
        span.add_attributes({ 'sw.is_entry_span' => true })
      rescue StandardError => e
        SolarWindsAPM.logger.info { "[#{self.class}/#{__method__}] processor on_start error: #{e.message}" }
      end

      # @param [Span] span the {Span} that just ended.
      def on_finish(span)
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] processor on_finish span: #{span.to_span_data.inspect}" }

        # return if span is non-entry span
        return if non_entry_span(span: span)

        record_request_metrics(span)
        record_sampling_metrics

        ::OpenTelemetry.meter_provider.metric_readers.each(&:pull)
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] processor on_finish succeed" }
      rescue StandardError => e
        SolarWindsAPM.logger.info { "[#{self.class}/#{__method__}] error processing span on_finish: #{e.message}" }
      end

      private

      # Create two meters for sampling and request count
      def init_meters
        {
          'sw.apm.sampling.metrics' => ::OpenTelemetry.meter_provider.meter('sw.apm.sampling.metrics'),
          'sw.apm.request.metrics' => ::OpenTelemetry.meter_provider.meter('sw.apm.request.metrics')
        }
      end

      def span_attributes(span)
        span_attrs = { 'sw.transaction' => calculate_lambda_transaction_name(span) }
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] span_attrs: #{span_attrs.inspect}" }
        span_attrs
      end

      def meter_attributes(span)
        meter_attrs = {
          'sw.is_error' => error?(span) == 1,
          'sw.transaction' => calculate_lambda_transaction_name(span)
        }

        if span_http?(span)
          http_status_code = get_http_status_code(span)
          meter_attrs['http.status_code'] = http_status_code if http_status_code != 0
          meter_attrs['http.method'] = span.attributes[HTTP_METHOD] if span.attributes[HTTP_METHOD]
        end
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] meter_attrs: #{meter_attrs.inspect}" }
        meter_attrs
      end

      def calculate_lambda_transaction_name(span)
        (ENV['SW_APM_TRANSACTION_NAME'] || ENV['AWS_LAMBDA_FUNCTION_NAME'] || span.name || 'unknown').slice(0, 255)
      end

      def init_metrics
        request_meter = @meters['sw.apm.request.metrics']
        sampling_meter = @meters['sw.apm.sampling.metrics']

        metrics = {}
        metrics[:response_time] = request_meter.create_histogram('trace.service.response_time', unit: 'ms', description: 'measures the duration of an inbound HTTP request')
        metrics[:tracecount]    = sampling_meter.create_counter('trace.service.tracecount')
        metrics[:samplecount]   = sampling_meter.create_counter('trace.service.samplecount')
        metrics[:request_count] = sampling_meter.create_counter('trace.service.request_count')
        metrics[:toex_count]    = sampling_meter.create_counter('trace.service.tokenbucket_exhaustion_count')
        metrics[:through_count] = sampling_meter.create_counter('trace.service.through_trace_count')
        metrics[:tt_count]      = sampling_meter.create_counter('trace.service.triggered_trace_count')
        metrics
      end

      def record_request_metrics(span)
        meter_attrs = meter_attributes(span)
        span_time = calculate_span_time(start_time: span.start_timestamp, end_time: span.end_timestamp)
        span_time = (span_time / 1e3).round
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] entry span, response_time: #{span_time}." }
        @metrics[:response_time].record(span_time, attributes: meter_attrs)
      end

      # oboe_api will return 0 in case of failed operation, and report 0 value
      def record_sampling_metrics
        _, trace_count = SolarWindsAPM.oboe_api.consumeTraceCount
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] trace_count: #{trace_count}" }
        @metrics[:tracecount].add(trace_count)

        _, sample_count = SolarWindsAPM.oboe_api.consumeSampleCount
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] sample_count: #{sample_count}" }
        @metrics[:samplecount].add(sample_count)

        _, request_count = SolarWindsAPM.oboe_api.consumeRequestCount
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] request_count: #{request_count}" }
        @metrics[:request_count].add(request_count)

        _, token_bucket_exhaustion_count = SolarWindsAPM.oboe_api.consumeTokenBucketExhaustionCount
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] tokenbucket_exhaustion_count: #{token_bucket_exhaustion_count}" }
        @metrics[:toex_count].add(token_bucket_exhaustion_count)

        _, through_trace_count = SolarWindsAPM.oboe_api.consumeThroughTraceCount
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] through_trace_count: #{through_trace_count}" }
        @metrics[:through_count].add(through_trace_count)

        _, triggered_trace_count = SolarWindsAPM.oboe_api.consumeTriggeredTraceCount
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] triggered_trace_count: #{triggered_trace_count}" }
        @metrics[:tt_count].add(triggered_trace_count)
      end
    end
  end
end
