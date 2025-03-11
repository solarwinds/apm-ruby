# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

# BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/sampling/http_sampler_test.rb

require 'minitest_helper'
require 'opentelemetry-metrics-sdk'
require 'opentelemetry-exporter-otlp-metrics'
require './lib/solarwinds_apm/sampling'

describe 'HttpSampler' do

  before do
    @config = {
      :collector => "https://#{ENV.fetch('SW_APM_COLLECTOR', 'apm.collector.cloud.solarwinds.com')}:443",
      :service => 'bbbbbbbb',
      :headers => "Bearer aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      :tracing_mode => true,
      :trigger_trace_enabled => true,
      :transaction_settings => true}
  end

  describe "valid service key" do
    before do
      new_config = @config.dup
      @sampler = SolarWindsAPM::HttpSampler.new(new_config)
      # otel.reset(trace: { sampler: @sampler })
      @sampler.wait_until_ready(1000)
    end

    it "samples created spans" do
      tracer = ::OpenTelemetry.tracer_provider.tracer("test")
      tracer.in_span("test") do |span|
        assert span.recording?, "Expected span to be recording"
      end

      span = otel.spans.first
      refute_nil span, "Expected span to be present"
      assert_includes span.attributes.keys, "SampleRate"
      assert_includes span.attributes.keys, "SampleSource"
      assert_includes span.attributes.keys, "BucketCapacity"
      assert_includes span.attributes.keys, "BucketRate"
    end
  end

  describe "invalid service key" do
    before do
      new_config = @config.merge(headers: { "Authorization" => "Bearer oh-no" })
      @sampler = SolarWindsAPM::HttpSampler.new(new_config)
      # otel.reset(trace: { sampler: @sampler })
      @sampler.wait_until_ready(1000)
    end

    it "does not sample created spans" do
      tracer = ::OpenTelemetry.tracer_provider.tracer("test")
      tracer.in_span("test") do |span|
        refute span.recording?, "Expected span to not be recording"
      end

      spans = otel.spans
      assert_empty spans, "Expected no spans to be created"
    end
  end

  describe "invalid collector" do
    before do
      new_config = @config.merge(collector: URI("https://collector.invalid"))
      @sampler = SolarWindsAPM::HttpSampler.new(new_config)
      # otel.reset(trace: { sampler: @sampler })
      @sampler.wait_until_ready(1000)
    end

    it "does not sample created spans" do
      tracer = ::OpenTelemetry.tracer_provider.tracer("test")
      tracer.in_span("test") do |span|
        refute span.recording?, "Expected span to not be recording"
      end

      spans = otel.spans
      assert_empty spans, "Expected no spans to be created"
    end

    it "retries with backoff" do
      sleep 1 # Simulating backoff delay
    end
  end
end
