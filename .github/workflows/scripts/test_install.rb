# Copyright (c) 2021 SolarWinds, LLC.
# All rights reserved.

# Test script used to check if a newly created gem installs and connects to
# the collector
# requires env vars:
# - SW_APM_SERVICE_KEY
# - SW_APM_COLLECTOR (optional if the key is for production)

require 'solarwinds_otel_apm'
require 'net/http'

unless SolarWindsOTelAPM::SDK.solarwinds_ready?(10_000)
  puts "aborting!!! Agent not ready after 10 seconds"
  exit false
end

op = lambda { 10.times {[9, 6, 12, 2, 7, 1, 9, 3, 4, 14, 5, 8].sort} }

SolarWindsOTelAPM.support_report

# no profiling yet for NH, but it shouldn't choke on Profiling.run
SolarWindsOTelAPM::Config[:profiling] = :disabled
Net::HTTP.get(URI('https://www.google.com'))
