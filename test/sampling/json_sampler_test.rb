# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

# BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/sampling/json_sampler_test.rb

require 'minitest_helper'
require 'opentelemetry-metrics-sdk'
require 'opentelemetry-exporter-otlp-metrics'
require './lib/solarwinds_apm/sampling'

describe 'JsonSampler Test' do
  def setup
    @sampler = SolarWindsAPM::JsonSampler.new({})
    @temp_path = './solarwinds-apm-settings.json'
  end

  describe "valid file" do
    before do
      File.write(@temp_path, JSON.dump([
        {
          flags: "SAMPLE_START,SAMPLE_THROUGH_ALWAYS,TRIGGER_TRACE,OVERRIDE",
          value: 1_000_000,
          arguments: { BucketCapacity: 100, BucketRate: 10 },
          timestamp: Time.now.to_i,
          ttl: 60
        }
      ]))
    end

    it "samples created spans" do
      tracer = ::OpenTelemetry.tracer_provider.tracer("test")
      tracer.in_span("test") do |span|
        assert span.recording?
        span.finish
      end
      
      # span = otel.spans.first
      refute_nil span
      assert_includes span.attributes.keys, :SampleRate
      assert_includes span.attributes.keys, :SampleSource
      assert_includes span.attributes.keys, :BucketCapacity
      assert_includes span.attributes.keys, :BucketRate
    end
  end

  describe "invalid file" do
    before do
      File.write(@temp_path, JSON.dump({ hello: "world" }))
    end

    it "does not sample created spans" do
      tracer = ::OpenTelemetry.tracer_provider.tracer("test")
      tracer.in_span("test") do |span|
        refute span.recording?
        span.finish
      end
      
      # assert_empty otel.spans
    end
  end

  describe "missing file" do
    before do
      FileUtils.rm_f(@temp_path)
    end

    it "does not sample created spans" do
      tracer = ::OpenTelemetry.tracer_provider.tracer("test")
      tracer.in_span("test") do |span|
        refute span.recording?
        span.finish
      end
      
      # assert_empty otel.spans
    end
  end

  describe "expired file" do
    before do
      File.write(@temp_path, JSON.dump([
        {
          flags: "SAMPLE_START,SAMPLE_THROUGH_ALWAYS,TRIGGER_TRACE,OVERRIDE",
          value: 1_000_000,
          arguments: { BucketCapacity: 100, BucketRate: 10 },
          timestamp: Time.now.to_i - 120,
          ttl: 60
        }
      ]))
    end

    it "does not sample created spans" do
      tracer = ::OpenTelemetry.tracer_provider.tracer("test")
      tracer.in_span("test") do |span|
        refute span.recording?
        span.finish
      end
      
      # assert_empty otel.spans
    end

    it "samples created span after reading new settings" do
      File.write(@temp_path, JSON.dump([
        {
          flags: "SAMPLE_START,SAMPLE_THROUGH_ALWAYS,TRIGGER_TRACE,OVERRIDE",
          value: 1_000_000,
          arguments: { BucketCapacity: 100, BucketRate: 10 },
          timestamp: Time.now.to_i,
          ttl: 60
        }
      ]))
      
      tracer = ::OpenTelemetry.tracer_provider.tracer("test")
      tracer.in_span("test") do |span|
        assert span.recording?
        span.finish
      end
      
      # span = otel.spans.first
      refute_nil span
      assert_includes span.attributes.keys, :SampleRate
      assert_includes span.attributes.keys, :SampleSource
      assert_includes span.attributes.keys, :BucketCapacity
      assert_includes span.attributes.keys, :BucketRate
    end
  end
end
