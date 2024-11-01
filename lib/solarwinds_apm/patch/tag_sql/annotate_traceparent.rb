# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

module SolarWindsAPM
  module Patch
    module TagSql
      module AnnotateTraceparent
        def self.generate_traceparent
          span_context = ::OpenTelemetry::Trace.current_span.context
          return '' if span_context == ::OpenTelemetry::Trace::SpanContext::INVALID

          trace_flag = span_context.trace_flags.sampled? ? '01' : '00'
          return '' if trace_flag == '00'

          format(
            '00-%<trace_id>s-%<span_id>s-%<trace_flags>.2d',
            trace_id: span_context.hex_trace_id,
            span_id: span_context.hex_span_id,
            trace_flags: trace_flag
          )
        rescue NameError => e
          SolarWindsAPM.logger.error { "[#{name}/#{__method__}] Couldn't find OpenTelemetry. Error: #{e.message}" }
          ''
        end
      end
    end
  end
end
