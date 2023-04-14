# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require_relative 'logger_formatter'

module SolarWindsOTelAPM
  module Logging
    module LogEvent
      include SolarWindsOTelAPM::Logger::Formatter # provides #insert_trace_id

      def initialize(logger, level, data, caller_tracing )
        return super if SolarWindsOTelAPM::Config[:log_traceId] == :never

        data = insert_trace_id(data)
        super
      end

    end
  end
end

if SolarWindsOTelAPM.loaded && defined?(Logging::LogEvent)
  Logging::LogEvent.send(:prepend, SolarWindsOTelAPM::Logging::LogEvent)
end
