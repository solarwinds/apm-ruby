# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require_relative './api/transaction_name'
require_relative './api/current_trace_info'
require_relative './api/initialization_report'
require_relative './api/transaction_settings'
require_relative './api/layerinit'
require_relative './api/tracing'

module SolarWindsOTelAPM
  module API
    extend SolarWindsOTelAPM::API::TransactionName
    extend SolarWindsOTelAPM::API::CurrentTraceInfo
    extend SolarWindsOTelAPM::API::InitializationReport
    extend SolarWindsOTelAPM::API::TransactionSettings
    extend SolarWindsOTelAPM::API::LayerInit
    extend SolarWindsOTelAPM::API::Tracing
  end
end