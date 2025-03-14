# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

# BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/sampling/json_sampler_test.rb

require 'minitest_helper'
require 'opentelemetry-metrics-sdk'
require 'opentelemetry-exporter-otlp-metrics'
require 'opentelemetry-test-helpers'
require './lib/solarwinds_apm/sampling'

describe 'JsonSampler Test' do
  let(:tracer) { ::OpenTelemetry.tracer_provider.tracer("test") }

  before do
    @temp_path = '/tmp/solarwinds-apm-settings.json'

    ENV['OTEL_TRACES_EXPORTER'] ='none'
    ::OpenTelemetry::SDK.configure

    @memory_exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    ::OpenTelemetry.tracer_provider.add_span_processor(::OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(@memory_exporter))
  end

  after do
    OpenTelemetry::TestHelpers.reset_opentelemetry
    @memory_exporter.reset
  end

  def replace_sampler(sampler)
    ::OpenTelemetry.tracer_provider.sampler = ::OpenTelemetry::SDK::Trace::Samplers.parent_based(
      root: sampler,
      remote_parent_sampled: sampler,
      remote_parent_not_sampled: sampler
    )
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
      sampler = SolarWindsAPM::JsonSampler.new({}, path = '/tmp/solarwinds-apm-settings.json')
      sleep(0.1)
      replace_sampler(sampler)

      tracer.in_span("test") do |span|
        assert span.recording?
        span.finish
      end

      span = @memory_exporter.finished_spans[0]

      refute_nil span
      assert_equal span.attributes.keys, ['SampleRate','SampleSource', 'BucketCapacity', 'BucketRate']
    end
  end

  describe "invalid file" do
    before do
      File.write(@temp_path, JSON.dump({ hello: "world" }))
    end

    it "does not sample created spans" do

      sampler = SolarWindsAPM::JsonSampler.new({}, path = '/tmp/solarwinds-apm-settings.json')
      replace_sampler(sampler)

      tracer.in_span("test") do |span|
        refute span.recording?
        span.finish
      end
      
      spans = @memory_exporter.finished_spans
      assert_empty spans
    end
  end

  describe "missing file" do
    before do
      FileUtils.rm_f(@temp_path)
    end

    it "does not sample created spans" do
      sampler = SolarWindsAPM::JsonSampler.new({}, path = '/tmp/solarwinds-apm-settings.json')
      replace_sampler(sampler)

      tracer.in_span("test") do |span|
        refute span.recording?
        span.finish
      end

      spans = @memory_exporter.finished_spans
      assert_empty spans
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
      sampler = SolarWindsAPM::JsonSampler.new({}, path = '/tmp/solarwinds-apm-settings.json')
      replace_sampler(sampler)

      tracer.in_span("test") do |span|
        refute span.recording?
        span.finish
      end
      
      spans = @memory_exporter.finished_spans
      assert_empty spans
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
      
      sampler = SolarWindsAPM::JsonSampler.new({}, path = '/tmp/solarwinds-apm-settings.json')
      replace_sampler(sampler)

      tracer.in_span("test") do |span|
        assert span.recording?
        span.finish
      end
      
      span = @memory_exporter.finished_spans[0]
      refute_nil span
      assert_equal span.attributes.keys, ['SampleRate','SampleSource', 'BucketCapacity', 'BucketRate']
    end
  end
end
