# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

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

Lumberjack::LogEntry.prepend(SolarWindsAPM::Lumberjack::LogEntry) if SolarWindsAPM.loaded && defined?(Lumberjack::LogEntry)
