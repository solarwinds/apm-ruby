module SolarWindsAPM
  module SDK
    module CurrentTraceInfo
      def current_trace_info
        TraceInfo.new
      end

      # @attr trace_id
      # @attr span_id
      # @attr trace_flags
      class TraceInfo
        attr_reader :tracestring, :trace_id, :span_id, :trace_flags, :do_log

        SQL_REGEX=/\/\*\s*traceparent=.*\*\/\s*/.freeze

        def initialize
          SolarWindsAPM.logger.warn {"SolarWindsAPM::SDK.current_trace_info will be depreciated soon. Please use SolarWindsAPM::API::CurrentTraceInfo"}
          @current_trace_info = SolarWindsAPM::API::CurrentTraceInfo.new
          
          @tracestring = @current_trace_info.tracestring
          @trace_id    = @current_trace_info.trace_id
          @span_id     = @current_trace_info.span_id
          @trace_flags = @current_trace_info.trace_flags

          @do_log      = @current_trace_info.do_log
          @do_sql      = SolarWindsAPM::Config[:tag_sql] && @trace_flags == '01'
        end

        def for_log
          SolarWindsAPM.logger.warn {"for_log in SolarWindsAPM::SDK.current_trace_info will be depreciated soon. Please use SolarWindsAPM::API::CurrentTraceInfo"}
          @current_trace_info.for_log
        end

        def hash_for_log
          SolarWindsAPM.logger.warn {"hash_for_log in SolarWindsAPM::SDK.current_trace_info will be depreciated soon. Please use SolarWindsAPM::API::CurrentTraceInfo"}
          @current_trace_info.hash_for_log
        end

        def for_sql
          SolarWindsAPM.logger.warn {"for_sql in SolarWindsAPM::SDK.current_trace_info will be depreciated soon. Please use SolarWindsAPM::API::CurrentTraceInfo"}
          @for_sql ||= @do_sql ? "/*traceparent='#{@tracestring}'*/" : ''
        end

        def add_traceparent_to_sql(sql, kvs)
          SolarWindsAPM.logger.warn {"add_traceparent_to_sql in SolarWindsAPM::SDK.current_trace_info will be depreciated soon. Please use SolarWindsAPM::API::CurrentTraceInfo"}
          SolarWindsAPM.logger.warn {"kvs are not used anymore."}
          sql = sql.gsub(SQL_REGEX, '') # remove if it was added before

          unless for_sql.empty?
            "#{for_sql}#{sql}"
          else
            sql
          end

        end

      end
    end

    extend CurrentTraceInfo
  end
end
