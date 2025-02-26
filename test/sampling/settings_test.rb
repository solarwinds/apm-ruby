# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

# BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/sampling/settings_test.rb

require 'minitest_helper'
require './lib/solarwinds_apm/sampling/sampling_constants'
require './lib/solarwinds_apm/sampling/settings'

describe 'SolarWindsAPM SamplingSettings Merge Test' do
  describe "merge" do
    describe "OVERRIDE is unset" do
      it "respects tracing mode NEVER & trigger mode disabled" do
        remote = {
          sampling_rate: 1,
          sample_source: SampleSource::LOCAL_DEFAULT,
          flags: Flags::SAMPLE_START | Flags::SAMPLE_THROUGH_ALWAYS | Flags::TRIGGERED_TRACE,
          buckets: {},
          timestamp: (Time.now.to_i),
          ttl: 60
        }
        local = {
          tracing_mode: TracingMode::NEVER,
          trigger_mode: false
        }

        merged = SolarWindsAPM::SamplingSettings.merge(remote, local)
        assert_equal({ flags: 0x0 }, merged.slice(:flags))
      end

      it "respects tracing mode ALWAYS & trigger mode enabled" do
        remote = {
          sample_rate: 1,
          sample_source: SampleSource::LOCAL_DEFAULT,
          flags: 0x0,
          buckets: {},
          timestamp: (Time.now.to_i),
          ttl: 60
        }
        local = {
          tracing_mode: TracingMode::ALWAYS,
          trigger_mode: true
        }

        merged = SolarWindsAPM::SamplingSettings.merge(remote, local)
        assert_equal({
          flags: Flags::SAMPLE_START | Flags::SAMPLE_THROUGH_ALWAYS | Flags::TRIGGERED_TRACE
        }, merged.slice(:flags))
      end

      it "defaults to remote value when local is unset" do
        remote = {
          sample_rate: 1,
          sample_source: SampleSource::LOCAL_DEFAULT,
          flags: Flags::SAMPLE_START | Flags::SAMPLE_THROUGH_ALWAYS | Flags::TRIGGERED_TRACE,
          buckets: {},
          timestamp: (Time.now.to_i),
          ttl: 60
        }
        local = {
          trigger_mode: true
        }

        merged = SolarWindsAPM::SamplingSettings.merge(remote, local)
        assert_equal(remote, merged)
      end
    end

    describe "OVERRIDE is set" do
      it "respects tracing mode NEVER & trigger mode disabled" do
        remote = {
          sample_rate: 1,
          sample_source: SampleSource::LOCAL_DEFAULT,
          flags: Flags::OVERRIDE | Flags::SAMPLE_START | Flags::SAMPLE_THROUGH_ALWAYS | Flags::TRIGGERED_TRACE,
          buckets: {},
          timestamp: (Time.now.to_i),
          ttl: 60
        }
        local = {
          tracing_mode: TracingMode::NEVER,
          trigger_mode: false
        }

        merged = SolarWindsAPM::SamplingSettings.merge(remote, local)
        assert_equal({ flags: Flags::OVERRIDE }, merged.slice(:flags))
      end

      it "does not respect tracing mode ALWAYS & trigger mode enabled" do
        remote = {
          sample_rate: 1,
          sample_source: SampleSource::LOCAL_DEFAULT,
          flags: Flags::OVERRIDE,
          buckets: {},
          timestamp: (Time.now.to_i),
          ttl: 60
        }
        local = {
          tracing_mode: TracingMode::ALWAYS,
          trigger_mode: true
        }

        merged = SolarWindsAPM::SamplingSettings.merge(remote, local)
        assert_equal(remote, merged)
      end

      it "defaults to remote value when local is unset" do
        remote = {
          sample_rate: 1,
          sample_source: SampleSource::LOCAL_DEFAULT,
          flags: Flags::OVERRIDE,
          buckets: {},
          timestamp: (Time.now.to_i),
          ttl: 60
        }
        local = {
          trigger_mode: false
        }

        merged = SolarWindsAPM::SamplingSettings.merge(remote, local)
        assert_equal(remote, merged)
      end
    end
  end
end

