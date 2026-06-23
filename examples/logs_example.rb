# frozen_string_literal: true

# © 2026 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

# This example demonstrates how to emit structured logs using the OpenTelemetry Logs API
# with solarwinds_apm. Log records are correlated with the current trace context and
# exported via the OTLP logs exporter configured by the gem.
#
# Usage:
#  OTEL_RUBY_INSTRUMENTATION_LOGGER_ENABLED=true \
#     SW_APM_SERVICE_KEY=<your-token>:my-service ruby logs_example.rb
#
# For console output during development, set:
#   OTEL_LOGS_EXPORTER=console

require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'
  gem 'solarwinds_apm', path: File.expand_path('..', __dir__)
end

puts '--- solarwinds_apm Logs Example ---'
puts

# --- Using the OpenTelemetry Logs API directly ---
# Access a Logger from the LoggerProvider configured by solarwinds_apm.

otel_logger = OpenTelemetry.logger_provider.logger(name: 'logs-example', version: '0.1.0')

# Emit log records within a trace span for correlation
tracer = OpenTelemetry.tracer_provider.tracer(ENV.fetch('OTEL_SERVICE_NAME', 'logs-example'))

tracer.in_span('example.logs_demo') do |_span|
  # Emit an INFO log record
  otel_logger.on_emit(
    timestamp: Time.now,
    severity_text: 'INFO',
    body: 'Application started successfully',
    attributes: { 'component' => 'startup', 'environment' => 'demo' }
  )
  puts 'Emitted INFO log: Application started successfully'

  # Emit a WARN log record
  otel_logger.on_emit(
    timestamp: Time.now,
    severity_text: 'WARN',
    body: 'Cache miss for key: user_preferences',
    attributes: { 'component' => 'cache', 'cache.key' => 'user_preferences' }
  )
  puts 'Emitted WARN log: Cache miss for key: user_preferences'

  # Show trace context available for log correlation
  trace_info = SolarWindsAPM::API.current_trace_info
  puts
  puts "Log records are correlated with trace_id: #{trace_info.trace_id}"
end

# Emit a log record outside of a span
otel_logger.on_emit(
  timestamp: Time.now,
  severity_text: 'DEBUG',
  body: 'Cleanup task completed',
  attributes: { 'component' => 'maintenance' }
)
puts 'Emitted DEBUG log (outside span): Cleanup task completed'

puts
puts 'Log records are exported via the OTLP logs exporter.'
puts '--- Logs example complete ---'
sleep 5 # Ensure logs are exported before the process exits
