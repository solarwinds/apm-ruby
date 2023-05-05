# Copyright (c) 2021 SolarWinds, LLC.
# All rights reserved.

# Test script used to check if a newly created gem installs and connects to
# the collector
# requires env vars:
# - SW_APM_SERVICE_KEY
# - SW_APM_COLLECTOR (optional if the key is for production)

require 'solarwinds_otel_apm'
require 'net/http'

unless SolarWindsOTelAPM.loaded
  puts "aborting!!! Agent not ready after 10 seconds"
  exit false
end

Net::HTTP.get(URI('https://www.google.com'))
