# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require_relative 'logger_formatter'

module SolarWindsAPM
  module Lumberjack
    module LogEntry
      include SolarWindsAPM::Logger::Formatter # provides #insert_trace_id

      def initialize(time, severity, message, progname, pid, tags)
        super if SolarWindsAPM::Config[:log_traceId] == :never

        message = insert_trace_id(message)
        super
      end
    end
  end
end

Lumberjack::LogEntry.prepend(SolarWindsAPM::Lumberjack::LogEntry) if defined?(Lumberjack::LogEntry)
