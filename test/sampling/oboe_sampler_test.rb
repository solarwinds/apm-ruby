# frozen_string_literal: true

# Copyright (c) 2025 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/sampling/sampling_constants'
require './lib/solarwinds_apm/sampling/token_bucket'
require './lib/solarwinds_apm/sampling/metrics'
require './lib/solarwinds_apm/sampling/trace_options'
require './lib/solarwinds_apm/sampling/oboe_sampler'
require './lib/solarwinds_apm/sampling/settings'
require './lib/solarwinds_apm/support/utils'
require './lib/solarwinds_apm/sampling/dice'
require 'sampling_test_helper'
require 'securerandom'
require 'openssl'

describe 'OboeSampler' do
  before do
    OpenTelemetry::SDK.configure
    @metric_exporter = OpenTelemetry::SDK::Metrics::Export::InMemoryMetricPullExporter.new
    OpenTelemetry.meter_provider.add_metric_reader(@metric_exporter)
  end

  describe 'LOCAL span' do
    it 'respects parent sampled' do
      sampler = OboeTestSampler.new(
        settings: {
          sample_rate: 0,
          sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
          flags: 0x0,
          buckets: {},
          timestamp: Time.now.to_i,
          ttl: 10
        },
        local_settings: { tracing_mode: false },
        request_headers: {}
      )

      parent = make_span({ remote: false, sampled: true })
      params = make_sample_params(parent: parent)

      sample = sampler.should_sample?(params)
      assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_AND_SAMPLE, sample.instance_variable_get(:@decision)

      check_counters(@metric_exporter, [])
    end

    it 'respects parent not sampled' do
      sampler = OboeTestSampler.new(
        settings: {
          sample_rate: 0,
          sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
          flags: 0x0,
          buckets: {},
          timestamp: Time.now.to_i,
          ttl: 10
        },
        local_settings: { tracing_mode: false },
        request_headers: {}
      )

      parent = make_span({ remote: false, sampled: false })
      params = make_sample_params(parent: parent)

      sample = sampler.should_sample?(params)
      assert_equal TEST_OTEL_SAMPLING_DECISION::DROP, sample.instance_variable_get(:@decision)

      check_counters(@metric_exporter, [])
    end
  end

  # BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/sampling/oboe_sampler_test.rb -n /invalid\ X-Trace-Options-Signature/
  describe 'invalid X-Trace-Options-Signature' do
    it 'rejects missing signature key' do
      sampler = OboeTestSampler.new(
        settings: {
          sample_rate: 1_000_000,
          sample_source: SolarWindsAPM::SampleSource::REMOTE,
          flags: SolarWindsAPM::Flags::SAMPLE_START | SolarWindsAPM::Flags::SAMPLE_THROUGH_ALWAYS,
          buckets: {},
          timestamp: Time.now.to_i,
          ttl: 10
        },
        local_settings: { trigger_mode: :enabled },
        request_headers: make_request_headers(
          trigger_trace: true,
          signature: true,
          kvs: { 'custom-key' => 'value' }
        )
      )

      parent = make_span({ remote: true, sampled: true })
      params = make_sample_params(parent: parent)

      sample = sampler.should_sample?(params)
      assert_equal TEST_OTEL_SAMPLING_DECISION::DROP, sample.instance_variable_get(:@decision)
      assert_empty sample.attributes
      assert_equal 'auth:no-signature-key', sample.tracestate['xtrace_options_response']

      check_counters(@metric_exporter, ['trace.service.request_count'])
    end

    # BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/sampling/oboe_sampler_test.rb -n /rejects\ bad\ timestamp/
    it 'rejects bad timestamp' do
      sampler = OboeTestSampler.new(
        settings: {
          sample_rate: 1_000_000,
          sample_source: SolarWindsAPM::SampleSource::REMOTE,
          flags: SolarWindsAPM::Flags::SAMPLE_START | SolarWindsAPM::Flags::SAMPLE_THROUGH_ALWAYS,
          buckets: {},
          signature_key: 'key'.b,
          timestamp: Time.now.to_i,
          ttl: 10
        },
        local_settings: { trigger_mode: :enabled },
        request_headers: make_request_headers(
          trigger_trace: true,
          signature: 'bad-timestamp',
          signature_key: 'key'.b,
          kvs: { 'custom-key' => 'value' }
        )
      )

      parent = make_span({ remote: true, sampled: true })
      params = make_sample_params(parent: parent)

      sample = sampler.should_sample?(params)
      assert_equal TEST_OTEL_SAMPLING_DECISION::DROP, sample.instance_variable_get(:@decision)
      assert_empty sample.attributes
      assert_equal 'auth:bad-timestamp', sample.tracestate['xtrace_options_response']

      check_counters(@metric_exporter, ['trace.service.request_count'])
    end

    # BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/sampling/oboe_sampler_test.rb -n /rejects\ bad\ signature/
    it 'rejects bad signature' do
      sampler = OboeTestSampler.new(
        settings: {
          sample_rate: 1_000_000,
          sample_source: SolarWindsAPM::SampleSource::REMOTE,
          flags: SolarWindsAPM::Flags::SAMPLE_START | SolarWindsAPM::Flags::SAMPLE_THROUGH_ALWAYS,
          buckets: {},
          signature_key: 'key1'.b,
          timestamp: Time.now.to_i,
          ttl: 10
        },
        local_settings: { trigger_mode: :enabled },
        request_headers: make_request_headers(
          trigger_trace: true,
          signature: true,
          signature_key: 'key2'.b,
          kvs: { 'custom-key' => 'value' }
        )
      )

      parent = make_span({ remote: true, sampled: true })
      params = make_sample_params(parent: parent)

      sample = sampler.should_sample?(params)
      assert_equal TEST_OTEL_SAMPLING_DECISION::DROP, sample.instance_variable_get(:@decision)
      assert_empty sample.attributes
      assert_equal 'auth:bad-signature', sample.tracestate['xtrace_options_response']

      check_counters(@metric_exporter, ['trace.service.request_count'])
    end
  end

  # BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/sampling/oboe_sampler_test.rb -n /missing\ settings/
  describe 'missing settings' do
    it "doesn't sample" do
      sampler = OboeTestSampler.new(
        settings: false,
        local_settings: { trigger_mode: :disabled },
        request_headers: {}
      )

      params = make_sample_params(parent: false)
      sample = sampler.should_sample?(params)
      assert_equal TEST_OTEL_SAMPLING_DECISION::DROP, sample.instance_variable_get(:@decision)

      check_counters(@metric_exporter, ['trace.service.request_count'])
    end

    it 'expires after ttl' do
      sampler = OboeTestSampler.new(
        settings: {
          sample_rate: 0,
          sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
          flags: SolarWindsAPM::Flags::SAMPLE_THROUGH_ALWAYS,
          buckets: {},
          timestamp: Time.now.to_i - 60,
          ttl: 10
        },
        local_settings: { trigger_mode: :disabled },
        request_headers: {}
      )

      parent = make_span(remote: true, sw: true, sampled: true)
      params = make_sample_params(parent: parent)

      sleep(0.01) # Simulating setTimeout(10)
      sample = sampler.should_sample?(params)
      assert_equal TEST_OTEL_SAMPLING_DECISION::DROP, sample.instance_variable_get(:@decision)

      check_counters(@metric_exporter, ['trace.service.request_count'])
    end

    it 'respects X-Trace-Options keys and values' do
      sampler = OboeTestSampler.new(
        settings: false,
        local_settings: { trigger_mode: :disabled },
        request_headers: make_request_headers(
          kvs: { 'custom-key' => 'value', 'sw-keys' => 'sw-values' }
        )
      )

      params = make_sample_params(parent: false)
      sample = sampler.should_sample?(params)
      assert_equal sample.attributes, { 'custom-key' => 'value', 'SWKeys' => 'sw-values' }
      assert_equal 'trigger-trace:not-requested', sample.tracestate['xtrace_options_response']
    end

    it 'ignores trigger-trace' do
      sampler = OboeTestSampler.new(
        settings: false,
        local_settings: { trigger_mode: :enabled },
        request_headers: make_request_headers(
          trigger_trace: true,
          kvs: { 'custom-key' => 'value', 'invalid-key' => 'value' }
        )
      )

      params = make_sample_params(parent: false)
      sample = sampler.should_sample?(params)
      assert_equal sample.attributes, { 'custom-key' => 'value' }
      assert_equal 'trigger-trace:settings-not-available;ignored:invalid-key', sample.tracestate['xtrace_options_response']
    end
  end

  # BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/sampling/oboe_sampler_test.rb -n /ENTRY\ span\ with\ valid\ sw\ context/
  describe 'ENTRY span with valid sw context' do
    describe 'X-Trace-Options' do
      it 'respects keys and values' do
        sampler = OboeTestSampler.new(
          settings: {
            sample_rate: 0,
            sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
            flags: SolarWindsAPM::Flags::SAMPLE_THROUGH_ALWAYS,
            buckets: {},
            timestamp: Time.now.to_i,
            ttl: 10
          },
          local_settings: { trigger_mode: :disabled },
          request_headers: make_request_headers(
            kvs: { 'custom-key' => 'value', 'sw-keys' => 'sw-values' }
          )
        )

        parent = make_span(remote: true, sw: true, sampled: true)
        params = make_sample_params(parent: parent)

        sample = sampler.should_sample?(params)
        _(sample.attributes['custom-key']).must_equal 'value'
        _(sample.attributes['SWKeys']).must_equal 'sw-values'
        assert_equal 'trigger-trace:not-requested', sample.tracestate['xtrace_options_response']
      end

      it 'ignores trigger-trace' do
        sampler = OboeTestSampler.new(
          settings: {
            sample_rate: 0,
            sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
            flags: SolarWindsAPM::Flags::SAMPLE_THROUGH_ALWAYS,
            buckets: {},
            timestamp: Time.now.to_i,
            ttl: 10
          },
          local_settings: { trigger_mode: :enabled },
          request_headers: make_request_headers(
            trigger_trace: true,
            kvs: { 'custom-key' => 'value', 'invalid-key' => 'value' }
          )
        )

        parent = make_span(remote: true, sw: true, sampled: true)
        params = make_sample_params(parent: parent)

        sample = sampler.should_sample?(params)
        _(sample.attributes['custom-key']).must_equal 'value'
        assert_equal 'trigger-trace:ignored;ignored:invalid-key', sample.tracestate['xtrace_options_response']
      end
    end

    describe 'SAMPLE_THROUGH_ALWAYS set' do
      before do
        @sampler = OboeTestSampler.new(
          settings: {
            sample_rate: 0,
            sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
            flags: SolarWindsAPM::Flags::SAMPLE_THROUGH_ALWAYS,
            buckets: {},
            timestamp: Time.now.to_i,
            ttl: 10
          },
          local_settings: { trigger_mode: :disabled },
          request_headers: {}
        )
      end

      it 'respects parent sampled' do
        parent = make_span(remote: true, sw: true, sampled: true)
        params = make_sample_params(parent: parent)

        sample = @sampler.should_sample?(params)
        assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_AND_SAMPLE, sample.instance_variable_get(:@decision)
        assert_equal sample.attributes, { 'sw.tracestate_parent_id' => parent.context.hex_span_id }

        check_counters(@metric_exporter, [
                         'trace.service.request_count',
                         'trace.service.tracecount',
                         'trace.service.through_trace_count'
                       ])
      end

      it 'respects parent not sampled' do
        parent = make_span(remote: true, sw: true, sampled: false)
        params = make_sample_params(parent: parent)

        sample = @sampler.should_sample?(params)
        assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_ONLY, sample.instance_variable_get(:@decision)
        assert_equal sample.attributes, { 'sw.tracestate_parent_id' => parent.context.hex_span_id }

        check_counters(@metric_exporter, ['trace.service.request_count'])
      end

      it 'respects sw sampled over w3c not sampled' do
        parent = make_span(remote: true, sw: 'inverse', sampled: false)
        params = make_sample_params(parent: parent)

        sample = @sampler.should_sample?(params)

        assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_AND_SAMPLE, sample.instance_variable_get(:@decision)
        assert_equal sample.attributes, { 'sw.tracestate_parent_id' => parent.context.hex_span_id }

        check_counters(@metric_exporter, [
                         'trace.service.request_count',
                         'trace.service.tracecount',
                         'trace.service.through_trace_count'
                       ])
      end

      it 'respects sw not sampled over w3c sampled' do
        parent = make_span(remote: true, sw: 'inverse', sampled: true)
        params = make_sample_params(parent: parent)

        sample = @sampler.should_sample?(params)
        assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_ONLY, sample.instance_variable_get(:@decision)
        assert_equal sample.attributes, { 'sw.tracestate_parent_id' => parent.context.hex_span_id }

        check_counters(@metric_exporter, ['trace.service.request_count'])
      end
    end

    describe 'SAMPLE_THROUGH_ALWAYS unset' do
      it 'records but does not sample when SAMPLE_START set' do
        sampler = OboeTestSampler.new(
          settings: {
            sample_rate: 0,
            sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
            flags: SolarWindsAPM::Flags::SAMPLE_START,
            buckets: {},
            timestamp: Time.now.to_i,
            ttl: 10
          },
          local_settings: { trigger_mode: :disabled },
          request_headers: {}
        )

        parent = make_span(remote: true, sw: true, sampled: true)
        params = make_sample_params(parent: parent)

        sample = sampler.should_sample?(params)
        assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_ONLY, sample.instance_variable_get(:@decision)

        check_counters(@metric_exporter, ['trace.service.request_count'])
      end

      it 'does not record or sample when SAMPLE_START unset' do
        sampler = OboeTestSampler.new(
          settings: {
            sample_rate: 0,
            sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
            flags: 0x0,
            buckets: {},
            timestamp: Time.now.to_i,
            ttl: 10
          },
          local_settings: { trigger_mode: :disabled },
          request_headers: {}
        )

        parent = make_span(remote: true, sw: true, sampled: true)
        params = make_sample_params(parent: parent)

        sample = sampler.should_sample?(params)
        assert_equal TEST_OTEL_SAMPLING_DECISION::DROP, sample.instance_variable_get(:@decision)

        check_counters(@metric_exporter, ['trace.service.request_count'])
      end
    end
  end

  # BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/sampling/oboe_sampler_test.rb -n /trigger-trace\ requested/
  describe 'trigger-trace requested' do
    describe 'TRIGGERED_TRACE set' do
      describe 'unsigned' do
        it 'records and samples when there is capacity' do
          sampler = OboeTestSampler.new(
            settings: {
              sample_rate: 0,
              sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
              flags: SolarWindsAPM::Flags::SAMPLE_START | SolarWindsAPM::Flags::TRIGGERED_TRACE,
              buckets: {
                SolarWindsAPM::BucketType::TRIGGER_STRICT => { capacity: 10, rate: 5 },
                SolarWindsAPM::BucketType::TRIGGER_RELAXED => { capacity: 0, rate: 0 }
              },
              timestamp: Time.now.to_i,
              ttl: 10
            },
            local_settings: { trigger_mode: :enabled },
            request_headers: make_request_headers(
              trigger_trace: true,
              kvs: { 'custom-key' => 'value', 'sw-keys' => 'sw-values' }
            )
          )
          parent = make_span(remote: true, sampled: true)
          params = make_sample_params(parent: parent)

          sample = sampler.should_sample?(params)
          assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_AND_SAMPLE, sample.instance_variable_get(:@decision)

          _(sample.attributes['custom-key']).must_equal 'value'
          _(sample.attributes['SWKeys']).must_equal 'sw-values'
          _(sample.attributes['BucketCapacity']).must_equal 10
          _(sample.attributes['BucketRate']).must_equal 5

          assert_equal 'trigger-trace:ok', sample.tracestate['xtrace_options_response']

          check_counters(@metric_exporter, [
                           'trace.service.request_count',
                           'trace.service.tracecount',
                           'trace.service.triggered_trace_count'
                         ])
        end

        it "records but doesn't sample when there is no capacity" do
          sampler = OboeTestSampler.new(
            settings: {
              sample_rate: 0,
              sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
              flags: SolarWindsAPM::Flags::SAMPLE_START | SolarWindsAPM::Flags::TRIGGERED_TRACE,
              buckets: {
                SolarWindsAPM::BucketType::TRIGGER_STRICT => { capacity: 0, rate: 0 },
                SolarWindsAPM::BucketType::TRIGGER_RELAXED => { capacity: 20, rate: 10 }
              },
              timestamp: Time.now.to_i,
              ttl: 10
            },
            local_settings: { trigger_mode: :enabled },
            request_headers: make_request_headers(
              trigger_trace: true,
              kvs: { 'custom-key' => 'value', 'invalid-key' => 'value' }
            )
          )

          parent = make_span(remote: true, sampled: true)
          params = make_sample_params(parent: parent)

          sample = sampler.should_sample?(params)
          assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_ONLY, sample.instance_variable_get(:@decision)

          _(sample.attributes['custom-key']).must_equal 'value'
          _(sample.attributes['BucketCapacity']).must_equal 0
          _(sample.attributes['BucketRate']).must_equal 0

          assert_equal 'trigger-trace:rate-exceeded;ignored:invalid-key', sample.tracestate['xtrace_options_response']

          check_counters(@metric_exporter, ['trace.service.request_count'])
        end
      end

      describe 'signed' do
        it 'records and samples when there is capacity' do
          sampler = OboeTestSampler.new(
            settings: {
              sample_rate: 0,
              sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
              flags: SolarWindsAPM::Flags::SAMPLE_START | SolarWindsAPM::Flags::TRIGGERED_TRACE,
              buckets: {
                SolarWindsAPM::BucketType::TRIGGER_STRICT => { capacity: 0, rate: 0 },
                SolarWindsAPM::BucketType::TRIGGER_RELAXED => { capacity: 20, rate: 10 }
              },
              signature_key: 'key',
              timestamp: Time.now.to_i,
              ttl: 10
            },
            local_settings: { trigger_mode: :enabled },
            request_headers: make_request_headers(
              trigger_trace: true,
              kvs: { 'custom-key' => 'value', 'sw-keys' => 'sw-values' },
              signature: true,
              signature_key: 'key'
            )
          )

          parent = make_span(remote: true, sampled: true)
          params = make_sample_params(parent: parent)

          sample = sampler.should_sample?(params)
          assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_AND_SAMPLE, sample.instance_variable_get(:@decision)

          _(sample.attributes['custom-key']).must_equal 'value'
          _(sample.attributes['SWKeys']).must_equal 'sw-values'
          _(sample.attributes['BucketCapacity']).must_equal 20
          _(sample.attributes['BucketRate']).must_equal 10

          assert_equal 'auth:ok;trigger-trace:ok', sample.tracestate['xtrace_options_response']

          check_counters(@metric_exporter, [
                           'trace.service.request_count',
                           'trace.service.tracecount',
                           'trace.service.triggered_trace_count'
                         ])
        end

        it "records but doesn't sample when there is no capacity" do
          sampler = OboeTestSampler.new(
            settings: {
              sample_rate: 0,
              sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
              flags: SolarWindsAPM::Flags::SAMPLE_START | SolarWindsAPM::Flags::TRIGGERED_TRACE,
              buckets: {
                SolarWindsAPM::BucketType::TRIGGER_STRICT => { capacity: 10, rate: 5 },
                SolarWindsAPM::BucketType::TRIGGER_RELAXED => { capacity: 0, rate: 0 }
              },
              signature_key: 'key',
              timestamp: Time.now.to_i,
              ttl: 10
            },
            local_settings: { trigger_mode: :enabled },
            request_headers: make_request_headers(
              trigger_trace: true,
              kvs: { 'custom-key' => 'value', 'invalid-key' => 'value' },
              signature: true,
              signature_key: 'key'
            )
          )

          parent = make_span(remote: true, sampled: true)
          params = make_sample_params(parent: parent)

          sample = sampler.should_sample?(params)
          assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_ONLY, sample.instance_variable_get(:@decision)

          _(sample.attributes['custom-key']).must_equal 'value'
          _(sample.attributes['BucketCapacity']).must_equal 0
          _(sample.attributes['BucketRate']).must_equal 0

          assert_equal 'auth:ok;trigger-trace:rate-exceeded;ignored:invalid-key', sample.tracestate['xtrace_options_response']

          check_counters(@metric_exporter, ['trace.service.request_count'])
        end
      end
    end

    describe 'TRIGGERED_TRACE unset' do
      it 'records but does not sample when TRIGGERED_TRACE is unset' do
        sampler = OboeTestSampler.new(
          settings: {
            sample_rate: 0,
            sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
            flags: SolarWindsAPM::Flags::SAMPLE_START,
            buckets: {},
            timestamp: Time.now.to_i,
            ttl: 10
          },
          local_settings: { trigger_mode: :disabled },
          request_headers: make_request_headers(
            trigger_trace: true,
            kvs: { 'custom-key' => 'value', 'invalid-key' => 'value' }
          )
        )

        parent = make_span(remote: true, sampled: true)
        params = make_sample_params(parent: parent)

        sample = sampler.should_sample?(params)
        assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_ONLY, sample.instance_variable_get(:@decision)
        assert_equal sample.attributes, { 'custom-key' => 'value' }
        assert_equal 'trigger-trace:trigger-tracing-disabled;ignored:invalid-key', sample.tracestate['xtrace_options_response']

        check_counters(@metric_exporter, ['trace.service.request_count'])
      end
    end
  end

  # BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/sampling/oboe_sampler_test.rb -n /dice\ roll/
  describe 'dice roll' do
    it 'respects X-Trace-Options keys and values' do
      sampler = OboeTestSampler.new(
        settings: {
          sample_rate: 0,
          sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
          flags: SolarWindsAPM::Flags::SAMPLE_START,
          buckets: {},
          timestamp: Time.now.to_i,
          ttl: 10
        },
        local_settings: { trigger_mode: :disabled },
        request_headers: make_request_headers(kvs: { 'custom-key' => 'value', 'sw-keys' => 'sw-values' })
      )

      parent = make_span(remote: true, sampled: false)
      params = make_sample_params(parent: parent)
      sample = sampler.should_sample?(params)

      _(sample.attributes['custom-key']).must_equal 'value'
      _(sample.attributes['SWKeys']).must_equal 'sw-values'

      assert_equal 'trigger-trace:not-requested', sample.tracestate['xtrace_options_response']
    end

    it 'records and samples when dice success and sufficient capacity' do
      sampler = OboeTestSampler.new(
        settings: {
          sample_rate: 1_000_000,
          sample_source: SolarWindsAPM::SampleSource::REMOTE,
          flags: SolarWindsAPM::Flags::SAMPLE_START,
          buckets: { SolarWindsAPM::BucketType::DEFAULT => { capacity: 10, rate: 5 } },
          timestamp: Time.now.to_i,
          ttl: 10
        },
        local_settings: { trigger_mode: :disabled },
        request_headers: {}
      )

      params = make_sample_params(parent: false)
      sample = sampler.should_sample?(params)

      assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_AND_SAMPLE, sample.instance_variable_get(:@decision)

      _(sample.attributes['SampleRate']).must_equal 1_000_000
      _(sample.attributes['SampleSource']).must_equal 6
      _(sample.attributes['BucketCapacity']).must_equal 10
      _(sample.attributes['BucketRate']).must_equal 5

      check_counters(@metric_exporter, ['trace.service.request_count', 'trace.service.samplecount', 'trace.service.tracecount'])
    end

    it "records but doesn't sample when dice success but insufficient capacity" do
      sampler = OboeTestSampler.new(
        settings: {
          sample_rate: 1_000_000,
          sample_source: SolarWindsAPM::SampleSource::REMOTE,
          flags: SolarWindsAPM::Flags::SAMPLE_START,
          buckets: { SolarWindsAPM::BucketType::DEFAULT => { capacity: 0, rate: 0 } },
          timestamp: Time.now.to_i,
          ttl: 10
        },
        local_settings: { trigger_mode: :disabled },
        request_headers: {}
      )

      params = make_sample_params(parent: false)
      sample = sampler.should_sample?(params)

      assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_ONLY, sample.instance_variable_get(:@decision)

      _(sample.attributes['SampleRate']).must_equal 1_000_000
      _(sample.attributes['SampleSource']).must_equal 6
      _(sample.attributes['BucketCapacity']).must_equal 0
      _(sample.attributes['BucketRate']).must_equal 0

      check_counters(@metric_exporter, ['trace.service.request_count', 'trace.service.samplecount', 'trace.service.tokenbucket_exhaustion_count'])
    end

    it "records but doesn't sample when dice failure" do
      sampler = OboeTestSampler.new(
        settings: {
          sample_rate: 0,
          sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
          flags: SolarWindsAPM::Flags::SAMPLE_START,
          buckets: { SolarWindsAPM::BucketType::DEFAULT => { capacity: 10, rate: 5 } },
          timestamp: Time.now.to_i,
          ttl: 10
        },
        local_settings: { trigger_mode: :disabled },
        request_headers: {}
      )

      params = make_sample_params(parent: false)
      sample = sampler.should_sample?(params)

      assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_ONLY, sample.instance_variable_get(:@decision)

      _(sample.attributes['SampleRate']).must_equal 0
      _(sample.attributes['SampleSource']).must_equal 2

      refute sample.attributes.key?(:BucketCapacity)
      refute sample.attributes.key?(:BucketRate)

      check_counters(@metric_exporter, ['trace.service.request_count', 'trace.service.samplecount'])
    end
  end

  # BUNDLE_GEMFILE=gemfiles/unit.gemfile bundle exec ruby -I test test/sampling/oboe_sampler_test.rb -n /SAMPLE_START\ unset/
  describe 'SAMPLE_START unset' do
    it 'ignores trigger-trace' do
      sampler = OboeTestSampler.new(
        settings: {
          sample_rate: 0,
          sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
          flags: 0x0,
          buckets: {},
          timestamp: Time.now.to_i,
          ttl: 10
        },
        local_settings: { trigger_mode: :enabled },
        request_headers: make_request_headers(
          trigger_trace: true,
          kvs: { 'custom-key' => 'value', 'invalid-key' => 'value' }
        )
      )

      parent = make_span(remote: true, sampled: true)
      params = make_sample_params(parent: parent)
      sample = sampler.should_sample?(params)

      _(sample.attributes['custom-key']).must_equal 'value'

      assert_equal 'trigger-trace:tracing-disabled;ignored:invalid-key', sample.tracestate['xtrace_options_response']
    end

    it 'records when SAMPLE_THROUGH_ALWAYS set' do
      sampler = OboeTestSampler.new(
        settings: {
          sample_rate: 0,
          sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
          flags: SolarWindsAPM::Flags::SAMPLE_THROUGH_ALWAYS,
          buckets: {},
          timestamp: Time.now.to_i,
          ttl: 10
        },
        local_settings: { trigger_mode: :disabled },
        request_headers: {}
      )

      parent = make_span(remote: true, sampled: true)
      params = make_sample_params(parent: parent)
      sample = sampler.should_sample?(params)

      assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_ONLY, sample.instance_variable_get(:@decision)
      check_counters(@metric_exporter, ['trace.service.request_count'])
    end

    it "doesn't record when SAMPLE_THROUGH_ALWAYS unset" do
      sampler = OboeTestSampler.new(
        settings: {
          sample_rate: 0,
          sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
          flags: 0x0,
          buckets: {},
          timestamp: Time.now.to_i,
          ttl: 10
        },
        local_settings: { trigger_mode: :disabled },
        request_headers: {}
      )

      parent = make_span(remote: true, sampled: true)
      params = make_sample_params(parent: parent)
      sample = sampler.should_sample?(params)

      assert_equal TEST_OTEL_SAMPLING_DECISION::DROP, sample.instance_variable_get(:@decision)
      check_counters(@metric_exporter, ['trace.service.request_count'])
    end
  end

  describe 'parent_based_algo' do
    it 'ignores trigger trace in parent-based algo' do
      sig_key = SecureRandom.random_bytes(8)
      headers = make_request_headers(trigger_trace: true, signature: true, signature_key: sig_key)

      sampler = OboeTestSampler.new(
        settings: {
          sample_rate: 1_000_000,
          sample_source: SolarWindsAPM::SampleSource::REMOTE,
          flags: SolarWindsAPM::Flags::SAMPLE_START | SolarWindsAPM::Flags::SAMPLE_THROUGH_ALWAYS | SolarWindsAPM::Flags::TRIGGERED_TRACE,
          buckets: {
            SolarWindsAPM::BucketType::DEFAULT => { capacity: 100, rate: 10 },
            SolarWindsAPM::BucketType::TRIGGER_RELAXED => { capacity: 100, rate: 10 },
            SolarWindsAPM::BucketType::TRIGGER_STRICT => { capacity: 100, rate: 10 }
          },
          timestamp: Time.now.to_i,
          ttl: 120,
          signature_key: sig_key
        },
        local_settings: { tracing_mode: SolarWindsAPM::TracingMode::ALWAYS, trigger_mode: :enabled },
        request_headers: headers
      )

      parent = make_span({ remote: true, sampled: true, sw: true })
      params = make_sample_params(parent: parent)

      result = sampler.should_sample?(params)
      puts "result: #{result.inspect}"
      assert_equal 'auth:ok;trigger-trace:ignored', result.tracestate['xtrace_options_response']
    end
  end

  describe 'trigger_trace_algo' do
    it 'records and samples with signed trigger trace (relaxed bucket)' do
      sig_key = SecureRandom.random_bytes(8)
      headers = make_request_headers(trigger_trace: true, signature: true, signature_key: sig_key)

      sampler = OboeTestSampler.new(
        settings: {
          sample_rate: 0,
          sample_source: SolarWindsAPM::SampleSource::REMOTE,
          flags: SolarWindsAPM::Flags::SAMPLE_START | SolarWindsAPM::Flags::TRIGGERED_TRACE,
          buckets: {
            SolarWindsAPM::BucketType::DEFAULT => { capacity: 100, rate: 10 },
            SolarWindsAPM::BucketType::TRIGGER_RELAXED => { capacity: 100, rate: 10 },
            SolarWindsAPM::BucketType::TRIGGER_STRICT => { capacity: 100, rate: 10 }
          },
          timestamp: Time.now.to_i,
          ttl: 120,
          signature_key: sig_key
        },
        local_settings: { tracing_mode: SolarWindsAPM::TracingMode::ALWAYS, trigger_mode: :enabled },
        request_headers: headers
      )

      parent = make_span({ remote: true, sampled: false })
      params = make_sample_params(parent: parent)

      result = sampler.should_sample?(params)
      assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_AND_SAMPLE, result.instance_variable_get(:@decision)
      assert_equal true, result.attributes['TriggeredTrace']
      assert_equal 'auth:ok;trigger-trace:ok', result.tracestate['xtrace_options_response']
    end

    it 'records and samples with unsigned trigger trace (strict bucket)' do
      headers = make_request_headers(trigger_trace: true)

      sampler = OboeTestSampler.new(
        settings: {
          sample_rate: 0,
          sample_source: SolarWindsAPM::SampleSource::REMOTE,
          flags: SolarWindsAPM::Flags::SAMPLE_START | SolarWindsAPM::Flags::TRIGGERED_TRACE,
          buckets: {
            SolarWindsAPM::BucketType::DEFAULT => { capacity: 100, rate: 10 },
            SolarWindsAPM::BucketType::TRIGGER_RELAXED => { capacity: 100, rate: 10 },
            SolarWindsAPM::BucketType::TRIGGER_STRICT => { capacity: 100, rate: 10 }
          },
          timestamp: Time.now.to_i,
          ttl: 120,
          signature_key: nil
        },
        local_settings: { tracing_mode: SolarWindsAPM::TracingMode::ALWAYS, trigger_mode: :enabled },
        request_headers: headers
      )

      parent = make_span({ remote: true, sampled: false })
      params = make_sample_params(parent: parent)

      result = sampler.should_sample?(params)
      assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_AND_SAMPLE, result.instance_variable_get(:@decision)
      assert_equal true, result.attributes['TriggeredTrace']
    end
  end

  describe 'settings management' do
    it 'rejects older settings' do
      sampler = OboeTestSampler.new(
        settings: {
          sample_rate: 1_000_000,
          sample_source: SolarWindsAPM::SampleSource::REMOTE,
          flags: SolarWindsAPM::Flags::SAMPLE_START,
          buckets: {},
          timestamp: Time.now.to_i,
          ttl: 120,
          signature_key: nil
        },
        local_settings: { tracing_mode: SolarWindsAPM::TracingMode::ALWAYS },
        request_headers: {}
      )

      # Attempt to update with older timestamp
      sampler.update_settings({
                                sample_rate: 0,
                                sample_source: SolarWindsAPM::SampleSource::LOCAL_DEFAULT,
                                flags: SolarWindsAPM::Flags::OK,
                                buckets: {},
                                timestamp: 1,
                                ttl: 1,
                                signature_key: nil
                              })

      parent = make_span({ remote: true, sampled: false })
      params = make_sample_params(parent: parent)

      result = sampler.should_sample?(params)
      # Should still use the original settings (SAMPLE_START set)
      assert_equal TEST_OTEL_SAMPLING_DECISION::RECORD_ONLY, result.instance_variable_get(:@decision)
    end
  end

  describe 'X-Trace-Options with sw-keys and custom keys' do
    it 'sets sw_keys and custom attributes' do
      headers = make_request_headers(trigger_trace: true, kvs: { 'sw-keys' => 'check-id:123,website:google', 'custom-key1' => 'value1' })

      sampler = OboeTestSampler.new(
        settings: {
          sample_rate: 0,
          sample_source: SolarWindsAPM::SampleSource::REMOTE,
          flags: SolarWindsAPM::Flags::SAMPLE_START | SolarWindsAPM::Flags::TRIGGERED_TRACE,
          buckets: {
            SolarWindsAPM::BucketType::DEFAULT => { capacity: 100, rate: 10 },
            SolarWindsAPM::BucketType::TRIGGER_RELAXED => { capacity: 100, rate: 10 },
            SolarWindsAPM::BucketType::TRIGGER_STRICT => { capacity: 100, rate: 10 }
          },
          timestamp: Time.now.to_i,
          ttl: 120,
          signature_key: nil
        },
        local_settings: { tracing_mode: SolarWindsAPM::TracingMode::ALWAYS, trigger_mode: :enabled },
        request_headers: headers
      )

      parent = make_span({ remote: true, sampled: false })
      params = make_sample_params(parent: parent)

      result = sampler.should_sample?(params)
      assert_equal 'check-id:123,website:google', result.attributes['SWKeys']
      assert_equal 'value1', result.attributes['custom-key1']
    end

    it 'sets not-requested trigger trace when no trigger-trace header' do
      headers = make_request_headers(kvs: { 'sw-keys' => 'check-id:123' })

      sampler = OboeTestSampler.new(
        settings: {
          sample_rate: 1_000_000,
          sample_source: SolarWindsAPM::SampleSource::REMOTE,
          flags: SolarWindsAPM::Flags::SAMPLE_START | SolarWindsAPM::Flags::SAMPLE_THROUGH_ALWAYS,
          buckets: {
            SolarWindsAPM::BucketType::DEFAULT => { capacity: 100, rate: 10 },
            SolarWindsAPM::BucketType::TRIGGER_RELAXED => { capacity: 100, rate: 10 },
            SolarWindsAPM::BucketType::TRIGGER_STRICT => { capacity: 100, rate: 10 }
          },
          timestamp: Time.now.to_i,
          ttl: 120,
          signature_key: nil
        },
        local_settings: { tracing_mode: SolarWindsAPM::TracingMode::ALWAYS },
        request_headers: headers
      )

      parent = make_span({ remote: true, sampled: false })
      params = make_sample_params(parent: parent)

      result = sampler.should_sample?(params)
      assert_equal 'trigger-trace:not-requested', result.tracestate['xtrace_options_response']
    end
  end

  describe 'generate_new_tracestate' do
    it 'creates new tracestate for invalid parent' do
      sampler = OboeTestSampler.new(
        settings: {
          sample_rate: 1_000_000,
          sample_source: SolarWindsAPM::SampleSource::REMOTE,
          flags: SolarWindsAPM::Flags::SAMPLE_START | SolarWindsAPM::Flags::SAMPLE_THROUGH_ALWAYS,
          buckets: {
            SolarWindsAPM::BucketType::DEFAULT => { capacity: 100, rate: 10 },
            SolarWindsAPM::BucketType::TRIGGER_RELAXED => { capacity: 100, rate: 10 },
            SolarWindsAPM::BucketType::TRIGGER_STRICT => { capacity: 100, rate: 10 }
          },
          timestamp: Time.now.to_i,
          ttl: 120,
          signature_key: nil
        },
        local_settings: { tracing_mode: SolarWindsAPM::TracingMode::ALWAYS },
        request_headers: {}
      )

      # ROOT span (no valid parent)
      params = make_sample_params(parent: nil)

      result = sampler.should_sample?(params)
      refute_nil result.tracestate
      assert_match(/^[0-9a-f]{16}-01$/, result.tracestate['sw'])
    end

    it 'updates existing tracestate for valid parent' do
      sampler = OboeTestSampler.new(
        settings: {
          sample_rate: 1_000_000,
          sample_source: SolarWindsAPM::SampleSource::REMOTE,
          flags: SolarWindsAPM::Flags::SAMPLE_START | SolarWindsAPM::Flags::SAMPLE_THROUGH_ALWAYS,
          buckets: {
            SolarWindsAPM::BucketType::DEFAULT => { capacity: 100, rate: 10 },
            SolarWindsAPM::BucketType::TRIGGER_RELAXED => { capacity: 100, rate: 10 },
            SolarWindsAPM::BucketType::TRIGGER_STRICT => { capacity: 100, rate: 10 }
          },
          timestamp: Time.now.to_i,
          ttl: 120,
          signature_key: nil
        },
        local_settings: { tracing_mode: SolarWindsAPM::TracingMode::ALWAYS },
        request_headers: {}
      )

      parent = make_span({ remote: true, sampled: true, sw: true })
      params = make_sample_params(parent: parent)

      result = sampler.should_sample?(params)
      assert_match(/^[0-9a-f]{16}-01$/, result.tracestate['sw'])
    end
  end

  describe 'spanType' do
    it 'identifies no parent as ROOT' do
      type = SolarWindsAPM::SpanType.span_type(nil)
      assert_equal SolarWindsAPM::SpanType::ROOT, type
    end

    it 'identifies invalid parent as ROOT' do
      parent = make_span({ id: 'woops' })

      type = SolarWindsAPM::SpanType.span_type(parent)
      assert_equal SolarWindsAPM::SpanType::ROOT, type
    end

    it 'identifies remote parent as ENTRY' do
      parent = make_span({ remote: true })

      type = SolarWindsAPM::SpanType.span_type(parent)
      assert_equal SolarWindsAPM::SpanType::ENTRY, type
    end

    it 'identifies local parent as LOCAL' do
      parent = make_span({ remote: false })

      type = SolarWindsAPM::SpanType.span_type(parent)
      assert_equal SolarWindsAPM::SpanType::LOCAL, type
    end
  end

  describe 'sw_from_span_and_decision' do
    it 'formats span_id-01 for RECORD_AND_SAMPLE' do
      sampler = OboeTestSampler.new(
        local_settings: {},
        request_headers: {}
      )
      parent = make_span({ remote: true, sampled: true })
      decision = TEST_OTEL_SAMPLING_DECISION::RECORD_AND_SAMPLE
      result = sampler.sw_from_span_and_decision(parent, decision)
      assert_equal "#{parent.context.hex_span_id}-01", result
    end

    it 'formats span_id-00 for DROP' do
      sampler = OboeTestSampler.new(
        local_settings: {},
        request_headers: {}
      )
      parent = make_span({ remote: true, sampled: false })
      decision = TEST_OTEL_SAMPLING_DECISION::DROP
      result = sampler.sw_from_span_and_decision(parent, decision)
      assert_equal "#{parent.context.hex_span_id}-00", result
    end
  end
end
