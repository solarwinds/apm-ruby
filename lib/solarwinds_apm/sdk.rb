# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require_relative './sdk/current_trace_info'
require_relative './sdk/custom_metrics'
require_relative './sdk/logging'
require_relative './sdk/trace_context_headers'
require_relative './sdk/tracing'

module SolarWindsAPM
  module SDK
    extend SolarWindsAPM::SDK::CurrentTraceInfo
    extend SolarWindsAPM::SDK::CustomMetrics
    extend SolarWindsAPM::SDK::Logging
    extend SolarWindsAPM::SDK::TraceContextHeaders
    extend SolarWindsAPM::SDK::Tracing
  end
end