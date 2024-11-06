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
          return '' unless span_context.trace_flags.sampled?

          format(
            '00-%<trace_id>s-%<span_id>s-%<trace_flags>.2d',
            trace_id: span_context.hex_trace_id,
            span_id: span_context.hex_span_id,
            trace_flags: '01' # if unsampled, won't reach to this step.
          )
        rescue NameError => e
          SolarWindsAPM.logger.error { "[#{name}/#{__method__}] Couldn't find OpenTelemetry. Error: #{e.message}" }
          ''
        end
      end
    end
  end
end
