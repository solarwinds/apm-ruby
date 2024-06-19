# Copyright (c) 2021 SolarWinds, LLC.
# All rights reserved.

# Test script used to check if a newly created gem install successfully
require 'solarwinds_apm'

unless SolarWindsAPM::API.solarwinds_ready?(10_000)
  puts "aborting!!! Agent not ready after 10 seconds"
  exit false
end

op = lambda { 10.times {[9, 6, 12, 2, 7, 1, 9, 3, 4, 14, 5, 8].sort} }

begin
  OpenTelemetry.tracer_provider.tracer(ENV['OTEL_SERVICE_NAME']).in_span('verify_install') do |span|
    op.call
    puts "Looks good!"
  end
  sleep 10
rescue StandardError => e
  puts "aborting!!! Agent error: #{e.message}"
  exit false
end
