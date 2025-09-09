# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  class Sampler < OboeSampler
    RUBY_SEM_CON = ::OpenTelemetry::SemanticConventions::Trace

    ATTR_HTTP_REQUEST_METHOD = 'http.request.method'
    ATTR_HTTP_METHOD = RUBY_SEM_CON::HTTP_METHOD
    ATTR_HTTP_RESPONSE_STATUS_CODE = 'http.response.status_code'
    ATTR_HTTP_STATUS_CODE = RUBY_SEM_CON::HTTP_STATUS_CODE
    ATTR_URL_SCHEME = 'url.scheme'
    ATTR_HTTP_SCHEME = RUBY_SEM_CON::HTTP_SCHEME
    ATTR_SERVER_ADDRESS = 'server.address'
    ATTR_NET_HOST_NAME = RUBY_SEM_CON::NET_HOST_NAME
    ATTR_URL_PATH = 'url.path'
    ATTR_HTTP_TARGET = RUBY_SEM_CON::HTTP_TARGET

    SW_XTRACEOPTIONS_KEY = 'sw_xtraceoptions'
    SW_SIGNATURE_KEY = 'sw_signature'

    # tracing_mode is getting from SolarWindsAPM::Config
    def initialize(config, logger)
      super(logger)
      @tracing_mode = resolve_tracing_mode(config)
      @trigger_mode = config[:trigger_trace_enabled]
      @transaction_settings = config[:transaction_settings]
      @ready = false
      @logger.debug { "[#{self.class}/#{__method__}] Sampler initialized: tracing_mode=#{@tracing_mode}, trigger_mode=#{@trigger_mode}, transaction_settings_count=#{@transaction_settings.inspect}" }
    end

    def wait_until_ready(timeout = 10)
      deadline = Time.now + timeout
      while Time.now < deadline
        # The @settings hash is populated by another thread (e.g., HttpSampler)
        unless @settings.empty?
          @ready = !@settings[:signature_key].nil?
          return @ready
        end
        sleep 0.1
      end

      @logger.warn { "[#{self.class}/#{__method__}] Timed out waiting for settings after #{timeout} seconds." }
      @ready # Will be false if timeout is reached
    end

    def resolve_tracing_mode(config)
      return unless config.key?(:tracing_mode) && !config[:tracing_mode].nil?

      config[:tracing_mode] ? TracingMode::ALWAYS : TracingMode::NEVER
    end

    def local_settings(params)
      _trace_id, _parent_context, _links, span_name, span_kind, attributes = params.values
      settings = { tracing_mode: @tracing_mode, trigger_mode: @trigger_mode }

      if @transaction_settings.nil? || @transaction_settings.empty?
        @logger.debug { "[#{self.class}/#{__method__}] No transaction settings, using defaults settings: #{settings.inspect}" }
      else
        http_metadata = http_span_metadata(span_kind, attributes)
        # below is for filter out unwanted transaction
        trans_settings = ::SolarWindsAPM::TransactionSettings.new(url_path: http_metadata[:url], name: span_name, kind: span_kind)
        tracing_mode   = trans_settings.calculate_trace_mode == 1 ? TracingMode::ALWAYS : TracingMode::NEVER

        settings[:tracing_mode] = tracing_mode
      end

      @logger.debug { "[#{self.class}/#{__method__}] Transaction settings after calculation #{settings.inspect}" }
      settings
    end

    # if context have sw-related value, it should be stored in context
    # named sw_xtraceoptions and sw_signature in header from propagator
    def request_headers(params)
      header, signature = obtain_traceoptions_signature(params[:parent_context])
      @logger.debug { "[#{self.class}/#{__method__}] trace_options header: #{header.inspect}, signature: #{signature.inspect} from parent_context: #{params[:parent_context].inspect}" }
      { 'X-Trace-Options' => header, 'X-Trace-Options-Signature' => signature }
    end

    def obtain_traceoptions_signature(context)
      header = context.value(SW_XTRACEOPTIONS_KEY)
      signature = context.value(SW_SIGNATURE_KEY)
      [header, signature]
    end

    def update_settings(settings)
      parsed = parse_settings(settings)
      if parsed
        @logger.debug { "[#{self.class}/#{__method__}] Valid settings #{parsed.inspect} from setting #{settings.inspect}" }
        @logger.warn { "Warning from parsed settings: #{parsed[:warning]}" } if parsed[:warning]
        super(parsed) # call oboe_sampler update_settings function to update the buckets
        parsed
      else
        @logger.debug { "[#{self.class}/#{__method__}] Invalid settings: #{settings.inspect}" }
        nil
      end
    end

    def http_span_metadata(kind, attributes)
      return { http: false } unless kind == ::OpenTelemetry::Trace::SpanKind::SERVER &&
                                    (attributes.key?(ATTR_HTTP_REQUEST_METHOD) || attributes.key?(ATTR_HTTP_METHOD))

      method_ = (attributes[ATTR_HTTP_REQUEST_METHOD] || attributes[ATTR_HTTP_METHOD]).to_s
      status = (attributes[ATTR_HTTP_RESPONSE_STATUS_CODE] || attributes[ATTR_HTTP_STATUS_CODE] || 0).to_i
      scheme = (attributes[ATTR_URL_SCHEME] || attributes[ATTR_HTTP_SCHEME] || 'http').to_s
      hostname = (attributes[ATTR_SERVER_ADDRESS] || attributes[ATTR_NET_HOST_NAME] || 'localhost').to_s
      path = (attributes[ATTR_URL_PATH] || attributes[ATTR_HTTP_TARGET]).to_s
      url = "#{scheme}://#{hostname}#{path}"

      http_metadata = {
        http: true,
        method: method_,
        status: status,
        scheme: scheme,
        hostname: hostname,
        path: path,
        url: url
      }

      @logger.debug { "[#{self.class}/#{__method__}] Retrieved http metadata: #{http_metadata.inspect}" }
      http_metadata
    end

    def parse_settings(unparsed)
      return unless unparsed.is_a?(Hash)

      sample_rate = unparsed['value']
      timestamp   = unparsed['timestamp']
      ttl         = unparsed['ttl']
      flags       = unparsed['flags']

      return unless sample_rate.is_a?(Numeric) &&
                    timestamp.is_a?(Numeric) &&
                    ttl.is_a?(Numeric)

      return unless flags.is_a?(String)

      flags = flags.split(',').reduce(Flags::OK) do |final_flag, f|
        flag = {
          'OVERRIDE' => Flags::OVERRIDE,
          'SAMPLE_START' => Flags::SAMPLE_START,
          'SAMPLE_THROUGH_ALWAYS' => Flags::SAMPLE_THROUGH_ALWAYS,
          'TRIGGER_TRACE' => Flags::TRIGGERED_TRACE
        }[f]

        final_flag |= flag if flag
        final_flag
      end

      buckets = {}
      signature_key = nil
      warning = nil

      if unparsed['arguments'].is_a?(Hash)
        args = unparsed['arguments']

        buckets[BucketType::DEFAULT] = { capacity: args['BucketCapacity'], rate: args['BucketRate'] } if args['BucketCapacity'].is_a?(Numeric) && args['BucketRate'].is_a?(Numeric)

        buckets['trigger_relaxed'] = { capacity: args['TriggerRelaxedBucketCapacity'], rate: args['TriggerRelaxedBucketRate'] } if args['TriggerRelaxedBucketCapacity'].is_a?(Numeric) && args['TriggerRelaxedBucketRate'].is_a?(Numeric)

        buckets['trigger_strict'] = { capacity: args['TriggerStrictBucketCapacity'], rate: args['TriggerStrictBucketRate'] } if args['TriggerStrictBucketCapacity'].is_a?(Numeric) && args['TriggerStrictBucketRate'].is_a?(Numeric)

        signature_key = args['SignatureKey'] if args['SignatureKey'].is_a?(String)
      end

      warning = unparsed['warning'] if unparsed['warning'].is_a?(String)

      {
        sample_source: SampleSource::REMOTE,
        sample_rate: sample_rate,
        flags: flags,
        timestamp: timestamp,
        ttl: ttl,
        buckets: buckets,
        signature_key: signature_key,
        warning: warning
      }
    end
  end
end
