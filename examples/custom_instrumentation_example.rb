# frozen_string_literal: true

# © 2026 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

# This example demonstrates the SolarWindsAPM::API::Tracer module, which provides
# the `add_tracer` method for automatically wrapping existing methods with trace spans.
#
# Usage:
#   SW_APM_SERVICE_KEY=<your-token>:my-service ruby custom_instrumentation_example.rb
#
# For console output during development, set:
#   OTEL_TRACES_EXPORTER=console

require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'
  gem 'solarwinds_apm', path: File.expand_path('..', __dir__)
end

puts '--- solarwinds_apm Custom Instrumentation Example ---'
puts

# Wait for the HttpSampler to receive tracing settings from the SolarWinds collector.
# solarwinds_apm replaces the default OTel sampler with a custom HttpSampler that fetches
# settings over HTTP on startup. Until settings arrive, all spans are dropped. This call
# blocks until the sampler is ready (or the timeout elapses).
unless SolarWindsAPM::API.solarwinds_ready?(10_000)
  warn '[solarwinds_apm] Not ready after 10 seconds — spans may not be sampled.'
end

# --- Using add_tracer to instrument instance methods ---
# Include SolarWindsAPM::API::Tracer and use add_tracer to automatically
# wrap method calls in a trace span.

class OrderProcessor
  include SolarWindsAPM::API::Tracer

  def process(order_id)
    puts "  Processing order #{order_id}..."
    validate(order_id)
    charge(order_id)
    puts "  Order #{order_id} processed."
  end

  def validate(order_id)
    sleep(0.02)
    puts "    Validated order #{order_id}"
  end

  def charge(order_id)
    sleep(0.03)
    puts "    Charged order #{order_id}"
  end

  # Instrument methods with custom span names
  add_tracer :process,  'order.process'
  add_tracer :validate, 'order.validate'
  add_tracer :charge,   'order.charge', kind: :internal
end

# --- Using add_tracer to instrument class methods ---

class NotificationService
  def self.send_email(to)
    sleep(0.01)
    puts "    Email sent to #{to}"
  end

  class << self
    include SolarWindsAPM::API::Tracer
    add_tracer :send_email, 'notification.send_email'
  end
end

# --- Run the instrumented code ---

processor = OrderProcessor.new

puts 'Processing orders with automatic span instrumentation:'
processor.process('ORD-1001')
puts

processor.process('ORD-1002')
puts

puts 'Sending notification with instrumented class method:'
NotificationService.send_email('customer@example.com')

puts
puts '--- Custom instrumentation example complete ---'
sleep 5 # Ensure spans are exported before the process exits
