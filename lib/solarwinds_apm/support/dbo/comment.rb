# frozen_string_literal: true

require 'opentelemetry-api'

module SolarWindsAPM
  module Dbo
    module Comment
      # always assume the comment should be the end of query statement
      def annotate_sql(sql)
        comment = construct_comment
        comment.present? && !sql.include?(comment) ? "#{sql} /*#{comment}*/" : sql
      end

      # We don't want to trace framework caches.
      # Only instrument SQL that directly hits the database.
      def ignore_payload?(name)
        %w[SCHEMA EXPLAIN CACHE].include?(name.to_s)
      end

      def self.construct_comment
        component_value = traceparent
        ret = "traceparent='#{component_value}'" if component_value.present?
        escape_sql_comment(ret)
      end

      def self.escape_sql_comment(str)
        str = str.gsub('/*', '').gsub('*/', '') while str.include?('/*') || str.include?('*/')
        str
      end

      ##
      # Insert trace string as traceparent to sql statement
      # Not insert if:
      #   there is no valid current trace context
      #   current trace context is not sampled
      #
      def self.traceparent
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
