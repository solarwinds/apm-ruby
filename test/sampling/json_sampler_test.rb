# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

# BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/sampling/json_sampler_test.rb
require 'minitest_helper'
require './lib/solarwinds_apm/sampling'
require 'sampling_test_helper'

describe 'JsonSampler Test' do
  let(:tracer) { OpenTelemetry.tracer_provider.tracer('test') }

  before do
    @temp_path = '/tmp/solarwinds-apm-settings.json'

    ENV['OTEL_TRACES_EXPORTER'] = 'none'
    OpenTelemetry::SDK.configure

    @memory_exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    OpenTelemetry.tracer_provider.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(@memory_exporter))
  end

  after do
    OpenTelemetry::TestHelpers.reset_opentelemetry
    @memory_exporter.reset
    FileUtils.rm_f(@temp_path)
  end

  describe 'valid file' do
    before do
      File.write(@temp_path, JSON.dump([
                                         {
                                           flags: 'SAMPLE_START,SAMPLE_THROUGH_ALWAYS,TRIGGER_TRACE,OVERRIDE',
                                           value: 1_000_000,
                                           arguments: { BucketCapacity: 100, BucketRate: 10 },
                                           timestamp: Time.now.to_i,
                                           ttl: 60
                                         }
                                       ]))
    end

    it 'samples created spans' do
      sampler = SolarWindsAPM::JsonSampler.new({}, '/tmp/solarwinds-apm-settings.json')
      sleep(0.1)
      replace_sampler(sampler)

      tracer.in_span('test') do |span|
        assert span.recording?
        span.finish
      end

      span = @memory_exporter.finished_spans[0]

      refute_nil span
      assert_equal span.attributes.keys, %w[SampleRate SampleSource BucketCapacity BucketRate]
    end
  end

  describe 'invalid file' do
    before do
      File.write(@temp_path, JSON.dump({ hello: 'world' }))
    end

    it 'does not sample created spans' do
      sampler = SolarWindsAPM::JsonSampler.new({}, '/tmp/solarwinds-apm-settings.json')
      replace_sampler(sampler)

      tracer.in_span('test') do |span|
        refute span.recording?
        span.finish
      end

      spans = @memory_exporter.finished_spans
      assert_empty spans
    end
  end

  describe 'missing file' do
    before do
      FileUtils.rm_f(@temp_path)
    end

    it 'does not sample created spans' do
      sampler = SolarWindsAPM::JsonSampler.new({}, '/tmp/solarwinds-apm-settings.json')
      replace_sampler(sampler)

      tracer.in_span('test') do |span|
        refute span.recording?
        span.finish
      end

      spans = @memory_exporter.finished_spans
      assert_empty spans
    end
  end

  describe 'expired file' do
    before do
      File.write(@temp_path, JSON.dump([
                                         {
                                           flags: 'SAMPLE_START,SAMPLE_THROUGH_ALWAYS,TRIGGER_TRACE,OVERRIDE',
                                           value: 1_000_000,
                                           arguments: { BucketCapacity: 100, BucketRate: 10 },
                                           timestamp: Time.now.to_i - 120,
                                           ttl: 60
                                         }
                                       ]))
    end

    it 'does not sample created spans' do
      sampler = SolarWindsAPM::JsonSampler.new({}, '/tmp/solarwinds-apm-settings.json')
      replace_sampler(sampler)

      tracer.in_span('test') do |span|
        refute span.recording?
        span.finish
      end

      spans = @memory_exporter.finished_spans
      assert_empty spans
    end

    it 'samples created span after reading new settings' do
      File.write(@temp_path, JSON.dump([
                                         {
                                           flags: 'SAMPLE_START,SAMPLE_THROUGH_ALWAYS,TRIGGER_TRACE,OVERRIDE',
                                           value: 1_000_000,
                                           arguments: { BucketCapacity: 100, BucketRate: 10 },
                                           timestamp: Time.now.to_i,
                                           ttl: 60
                                         }
                                       ]))

      sampler = SolarWindsAPM::JsonSampler.new({}, '/tmp/solarwinds-apm-settings.json')
      replace_sampler(sampler)

      tracer.in_span('test') do |span|
        assert span.recording?
        span.finish
      end

      span = @memory_exporter.finished_spans[0]
      refute_nil span
      assert_equal span.attributes.keys, %w[SampleRate SampleSource BucketCapacity BucketRate]
    end
  end

  it 'handles invalid JSON file content' do
    File.write(@temp_path, 'not valid json{{{')
    logged_msg = nil
    SolarWindsAPM.logger.stub(:error, ->(_msg = nil, &block) { logged_msg = block&.call }) do
      sampler = SolarWindsAPM::JsonSampler.new({}, @temp_path)
      refute_nil sampler
    end
    refute_nil logged_msg
    assert_match(/JSON parsing error in #{Regexp.escape(@temp_path)}/, logged_msg)
  end

  it 'handles invalid settings structure (not single element array)' do
    File.write(@temp_path, JSON.dump([{ flags: 'a' }, { flags: 'b' }]))
    logged_msg = nil
    SolarWindsAPM.logger.stub(:error, ->(_msg = nil, &block) { logged_msg = block&.call }) do
      sampler = SolarWindsAPM::JsonSampler.new({}, @temp_path)
      refute_nil sampler
    end
    refute_nil logged_msg
    assert_match(/Invalid settings file content/, logged_msg)
  end

  it 'handles empty array in settings file' do
    File.write(@temp_path, JSON.dump([]))
    logged_msg = nil
    SolarWindsAPM.logger.stub(:error, ->(_msg = nil, &block) { logged_msg = block&.call }) do
      sampler = SolarWindsAPM::JsonSampler.new({}, @temp_path)
      refute_nil sampler
    end
    refute_nil logged_msg
    assert_match(/Invalid settings file content/, logged_msg)
  end

  it 'skips loop_check when settings not expired' do
    File.write(@temp_path, JSON.dump([
                                       {
                                         'flags' => 'SAMPLE_START,SAMPLE_THROUGH_ALWAYS',
                                         'value' => 1_000_000,
                                         'arguments' => { 'BucketCapacity' => 100, 'BucketRate' => 10 },
                                         'timestamp' => Time.now.to_i,
                                         'ttl' => 600
                                       }
                                     ]))
    sampler = SolarWindsAPM::JsonSampler.new({}, @temp_path)

    # loop_check sets @expiry = timestamp + ttl (far future), so the next call returns early
    # @expiry must be unchanged, proving loop_check returned early without re-reading the file
    expiry_before = sampler.instance_variable_get(:@expiry)
    params = make_sample_params
    sampler.should_sample?(params)
    assert_equal expiry_before, sampler.instance_variable_get(:@expiry)
  end

  it 'does not re-read when file mtime unchanged' do
    File.write(@temp_path, JSON.dump([
                                       {
                                         'flags' => 'SAMPLE_START,SAMPLE_THROUGH_ALWAYS',
                                         'value' => 500_000,
                                         'arguments' => { 'BucketCapacity' => 50, 'BucketRate' => 5 },
                                         'timestamp' => Time.now.to_i - 60,
                                         'ttl' => 10
                                       }
                                     ]))
    sampler = SolarWindsAPM::JsonSampler.new({}, @temp_path)
    sleep(0.1)

    # Force expiry into the past so loop_check will pass `return if Time.now.to_i < @expiry - 10`
    # Since the file mtime is unchanged, loop_check should return early and not update @expiry
    forced_expiry = Time.now.to_i - 100
    sampler.instance_variable_set(:@expiry, forced_expiry)
    params = make_sample_params
    sampler.should_sample?(params)
    assert_equal forced_expiry, sampler.instance_variable_get(:@expiry)
  end

  it 'updates expiry when settings are expired and no prior mtime recorded' do
    # Sampler is created with a missing file so loop_check on init returns early without
    # setting @last_mtime, leaving it nil. The mtime guard is then skipped on the next call.
    FileUtils.rm_f(@temp_path)
    sampler = SolarWindsAPM::JsonSampler.new({}, @temp_path)
    assert_nil sampler.instance_variable_get(:@last_mtime)

    new_timestamp = Time.now.to_i
    new_ttl = 300
    File.write(@temp_path, JSON.dump([
                                       {
                                         'flags' => 'SAMPLE_START,SAMPLE_THROUGH_ALWAYS',
                                         'value' => 1_000_000,
                                         'arguments' => { 'BucketCapacity' => 100, 'BucketRate' => 10 },
                                         'timestamp' => new_timestamp,
                                         'ttl' => new_ttl
                                       }
                                     ]))

    # Force expiry into the past so the time guard is cleared
    sampler.instance_variable_set(:@expiry, Time.now.to_i - 100)
    params = make_sample_params
    sampler.should_sample?(params)

    # @expiry must now reflect the newly read file content
    assert_equal new_timestamp + new_ttl, sampler.instance_variable_get(:@expiry)
  end

  it 'updates expiry when settings are expired and file has changed since last read' do
    File.write(@temp_path, JSON.dump([
                                       {
                                         'flags' => 'SAMPLE_START,SAMPLE_THROUGH_ALWAYS',
                                         'value' => 500_000,
                                         'arguments' => { 'BucketCapacity' => 50, 'BucketRate' => 5 },
                                         'timestamp' => Time.now.to_i - 60,
                                         'ttl' => 10
                                       }
                                     ]))
    sampler = SolarWindsAPM::JsonSampler.new({}, @temp_path)
    # @last_mtime is now set to the initial file's mtime
    refute_nil sampler.instance_variable_get(:@last_mtime)

    # sleep to guarantee the next write gets a strictly newer mtime
    sleep(1)

    new_timestamp = Time.now.to_i
    new_ttl = 300
    File.write(@temp_path, JSON.dump([
                                       {
                                         'flags' => 'SAMPLE_START,SAMPLE_THROUGH_ALWAYS',
                                         'value' => 1_000_000,
                                         'arguments' => { 'BucketCapacity' => 100, 'BucketRate' => 10 },
                                         'timestamp' => new_timestamp,
                                         'ttl' => new_ttl
                                       }
                                     ]))

    # Force expiry into the past so the time guard is cleared
    sampler.instance_variable_set(:@expiry, Time.now.to_i - 100)
    params = make_sample_params
    sampler.should_sample?(params)

    # @expiry must now equal timestamp + ttl from the updated file
    assert_equal new_timestamp + new_ttl, sampler.instance_variable_get(:@expiry)
  end
end
