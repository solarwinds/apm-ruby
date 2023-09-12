# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require_relative './sdk/custom_metrics'

module SolarWindsAPM
  module SDK
    extend SolarWindsAPM::SDK::CustomMetrics
  end
end