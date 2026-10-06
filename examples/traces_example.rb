# frozen_string_literal: true

# © 2026 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

# This example demonstrates how to create custom trace spans using solarwinds_apm.
# It shows both the standard OpenTelemetry API and the SolarWindsAPM convenience API.
#
# Usage:
#   SW_APM_SERVICE_KEY=<your-token>:my-service ruby traces_example.rb
#
# For console output during development, set:
#   OTEL_TRACES_EXPORTER=console

require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'
  gem 'solarwinds_apm', path: File.expand_path('..', __dir__)
end

puts '--- solarwinds_apm Traces Example ---'
puts "Service: #{ENV.fetch('OTEL_SERVICE_NAME', '(auto-detected from SW_APM_SERVICE_KEY)')}"
puts

# Wait for the HttpSampler to receive tracing settings from the SolarWinds collector.
# solarwinds_apm replaces the default OTel sampler with a custom HttpSampler that fetches
# settings over HTTP on startup. Until settings arrive, all spans are dropped. This call
# blocks until the sampler is ready (or the timeout elapses).
warn '[solarwinds_apm] Not ready after 10 seconds — spans may not be sampled.' unless SolarWindsAPM::API.solarwinds_ready?(10_000)

# --- Using the SolarWindsAPM convenience API ---
# SolarWindsAPM::API.in_span acquires the correct Tracer automatically.

SolarWindsAPM::API.in_span('example.greeting', attributes: { 'greeting.language' => 'en' }) do |span|
  message = 'Hello from solarwinds_apm!'
  span.add_event('greeting.generated', attributes: { 'message' => message })
  puts "Generated greeting: #{message}"
end

puts
puts '--- Traces example complete ---'
sleep 5 # Ensure spans are exported before the process exits
