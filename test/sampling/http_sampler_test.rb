# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

# BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/sampling/http_sampler_test.rb
require 'minitest_helper'
require 'opentelemetry-metrics-sdk'
require 'opentelemetry-exporter-otlp-metrics'
require 'opentelemetry-test-helpers'
require './lib/solarwinds_apm/sampling'

module HttpSamplerTestPatch
  def retry_request; end
  def settings_request(timeout = nil)
    if @setting_url.hostname == "collector.invalid"
      response = fetch_with_timeout(@setting_url)
      parsed = response.nil? ? {"value"=>0, "flags"=>"OVERRIDE", "timestamp"=>1741963365, "ttl"=>120, "arguments"=>{"BucketCapacity"=>0, "BucketRate"=>0, "TriggerRelaxedBucketCapacity"=>0, "TriggerRelaxedBucketRate"=>0, "TriggerStrictBucketCapacity"=>0, "TriggerStrictBucketRate"=>0}, "warning"=>"Test Warning"} : JSON.parse(response.body)

      unless update_settings(parsed)
        @logger.warn { 'Retrieved sampling settings are invalid. Ensure proper configuration.' }
        retry_request
      end
    else
      super(timeout=timeout)
    end
  end
end
SolarWindsAPM::HttpSampler.prepend(HttpSamplerTestPatch)

describe 'HttpSampler' do
  let(:tracer) { ::OpenTelemetry.tracer_provider.tracer("test") }
  before do
    ENV['OTEL_TRACES_EXPORTER'] ='none'
    ::OpenTelemetry::SDK.configure

    @memory_exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    ::OpenTelemetry.tracer_provider.add_span_processor(::OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(@memory_exporter))

    @config = {
      :collector => "https://apm.collector.st-ssp.solarwinds.com:443",
      :service => 'test-ruby',
      :headers => "Bearer #{ENV['APM_RUBY_TEST_STAGING_KEY']}",
      :tracing_mode => true,
      :trigger_trace_enabled => true}
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

  describe "valid service key" do
    it "samples created spans" do
      new_config = @config.dup
      sampler = SolarWindsAPM::HttpSampler.new(new_config)
      replace_sampler(sampler)
      sampler.wait_until_ready(1000)

      tracer.in_span("test") do |span|
        assert span.recording?
      end

      span = @memory_exporter.finished_spans[0]

      refute_nil span
      assert_equal span.attributes.keys, ['SampleRate','SampleSource', 'BucketCapacity', 'BucketRate']
    end
  end

  describe "invalid service key" do
    it "does not sample created spans" do
      new_config = @config.merge(headers: "Bearer oh-no")
      sampler = SolarWindsAPM::HttpSampler.new(new_config)
      replace_sampler(sampler)
      sampler.wait_until_ready(1000)

      tracer.in_span("test") do |span|
        refute span.recording?
      end

      spans = @memory_exporter.finished_spans
      assert_empty spans
    end
  end

  describe "invalid collector" do
    it "does not sample created spans xuan" do
      new_config = @config.merge(collector: URI("https://collector.invalid"))
      sampler = SolarWindsAPM::HttpSampler.new(new_config)
      replace_sampler(sampler)
      sampler.wait_until_ready(1000)

      tracer.in_span("test") do |span|
        refute span.recording?
      end

      spans = @memory_exporter.finished_spans
      assert_empty spans
    end

    it "retries with backoff" do
      sleep 1 # Simulating backoff delay
    end
  end
end
