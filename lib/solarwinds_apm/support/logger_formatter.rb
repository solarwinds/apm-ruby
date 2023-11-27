# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'logger'

module SolarWindsAPM
  module Logger
    module Formatter
      def call(severity, time, progname, msg)
        return super if SolarWindsAPM::Config[:log_traceId] == :never

        msg = insert_trace_id(msg)
        super
      end

      private

      def insert_trace_id(msg)
        return msg if /trace_id=/.match?(msg)

        current_trace = SolarWindsAPM::API.current_trace_info
        if current_trace.do_log
          case msg
          when ::String
            msg = msg.strip.empty? ? msg : insert_before_empty_lines(msg, current_trace.for_log)
          when ::Exception
            # conversion to String copied from Logger::Formatter private method #msg2str
            msg = ("#{msg.message} (#{msg.class}) #{current_trace.for_log}\n" <<
              (msg.backtrace || []).join("\n"))
          end
        end
        msg
      end

      def insert_before_empty_lines(msg, for_log)
        stripped = msg.rstrip
        "#{stripped} #{for_log}#{msg[stripped.length..]}"
      end
    end
  end
end

# To use the trace context in log, ::Logger::Formatter.new must be defined
# e.g. config.log_formatter = ::Logger::Formatter.new
Logger::Formatter.prepend(SolarWindsAPM::Logger::Formatter) if SolarWindsAPM.loaded
