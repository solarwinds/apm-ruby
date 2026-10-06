# frozen_string_literal: true

# © 2026 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

# This example demonstrates how to create and record custom metrics using solarwinds_apm.
# solarwinds_apm initializes a global MeterProvider so your application can create
# Meters and Instruments using the standard OpenTelemetry Metrics API.
#
# Usage:
#   OTEL_METRIC_EXPORT_INTERVAL=2000 SW_APM_SERVICE_KEY=<your-token>:my-service ruby metrics_example.rb
#
# For console output during development, set:
#   OTEL_METRICS_EXPORTER=console

require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'
  gem 'solarwinds_apm', path: File.expand_path('..', __dir__)
end

puts '--- solarwinds_apm Metrics Example ---'
puts

# Acquire a Meter from the globally-configured MeterProvider
meter = OpenTelemetry.meter_provider.meter('metrics-example')

# --- Counter ---
# Counts the number of times an event occurs.

request_counter = meter.create_counter(
  'app.requests',
  description: 'Total number of requests processed',
  unit: '{request}'
)

5.times do |i|
  request_counter.add(1, attributes: { 'http.method' => 'GET', 'http.route' => '/api/users' })
  puts "Recorded request #{i + 1}"
end

# --- UpDownCounter ---
# Tracks a value that can increase or decrease, such as active connections.

active_connections = meter.create_up_down_counter(
  'app.active_connections',
  description: 'Number of active connections',
  unit: '{connection}'
)

3.times { active_connections.add(1, attributes: { 'server.region' => 'us-east-1' }) }
puts 'Opened 3 connections'

active_connections.add(-1, attributes: { 'server.region' => 'us-east-1' })
puts 'Closed 1 connection (2 remaining)'

# --- Histogram ---
# Records a distribution of values, such as request duration.

duration_histogram = meter.create_histogram(
  'app.request.duration',
  description: 'Request duration distribution',
  unit: 'ms'
)

[12.5, 45.3, 8.1, 102.7, 23.4].each do |duration|
  duration_histogram.record(duration, attributes: { 'http.method' => 'GET', 'http.status_code' => 200 })
  puts "Recorded request duration: #{duration}ms"
end

puts
puts 'Metrics are aggregated and exported every 2 seconds by the configured exporter.'
puts '--- Metrics example complete ---'
sleep 5 # Ensure metrics are exported before the process exits
