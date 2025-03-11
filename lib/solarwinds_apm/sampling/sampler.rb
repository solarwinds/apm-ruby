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
    ATTR_HTTP_RESPONSE_STATUS_CODE =  'http.response.status_code'
    ATTR_HTTP_STATUS_CODE = RUBY_SEM_CON::HTTP_STATUS_CODE
    ATTR_URL_SCHEME = 'url.scheme'
    ATTR_HTTP_SCHEME = RUBY_SEM_CON::HTTP_SCHEME
    ATTR_SERVER_ADDRESS = 'server.address'
    ATTR_NET_HOST_NAME = RUBY_SEM_CON::NET_HOST_NAME
    ATTR_URL_PATH = 'url.path'
    ATTR_HTTP_TARGET = RUBY_SEM_CON::HTTP_TARGET

    # tracing_mode is getting from SolarWindsAPM::Config
    def initialize(config, logger)
      super(logger)
      @tracing_mode = config[:tracing_mode] ? ::TracingMode::ALWAYS : ::TracingMode::NEVER if config.key?(:tracing_mode)
      @trigger_mode = config[:trigger_trace_enabled]
      @transaction_settings = config[:transaction_settings]
      @ready = false
    end

    # wait for getting the first settings
    def wait_until_ready(timeout = 10)
      Timeout.timeout(timeout) do
        settings_ready
      end
    end

    def settings_ready
      while true
        break if !@settings.empty?
      end
    end

    def local_settings(params)
      _trace_id, _parent_context, _links, span_name, span_kind, attributes = params.values
      settings = { tracing_mode: @tracing_mode, trigger_mode: @trigger_mode }
      return settings if @transaction_settings.nil? || @transaction_settings.empty?

      @logger.debug { "Current @transaction_settings: #{@transaction_settings.inspect}" }
      http_metadata = http_span_metadata(span_kind, attributes)
      @logger.debug { "http_metadata: #{http_metadata.inspect}"}

      # below is for filter out unwanted transaction
      trans_settings = SolarWindsAPM::TransactionSettings.new(url_path: http_metadata[:url], name: span_name, kind: span_kind)
      tracing_mode   = trans_settings.calculate_trace_mode == 1 ? ::TracingMode::ALWAYS : ::TracingMode::NEVER

      settings[:tracing_mode] = tracing_mode
      settings
    end

    # if context have sw-related value, it should be stored in context
    # named sw_xtraceoptions in header propagator
    # original x_trace_options will parse headers in the class, apm-js separate the task
    # apm-js will make headers as hash
    def request_headers(params)
      parent_context = params[:parent_context]

      header = obtain_sw_value(parent_context, 'sw_xtraceoptions')
      signature = obtain_sw_value(parent_context, 'sw_signature')
      @logger.debug { "[#{self.class}/#{__method__}] trace_options option_header: #{header}; trace_options sw_signature: #{signature}" }

      {
        'X-Trace-Options' => header,
        'X-Trace-Options-Signature' => signature
      }
    end

    def obtain_sw_value(context, type)
      sw_value = nil
      instance_variable = context&.instance_variable_get('@entries')
      instance_variable&.each do |key, value|
        next unless key.instance_of?(::String)

        sw_value = value if key == type
      end
      sw_value
    end

    def update_settings(settings)
      parsed = parse_settings(settings)
      if parsed
        @logger.debug {"valid settings #{parsed.inspect} from setting #{settings.inspect}"}

        super(parsed)  # call oboe_sampler update_settings function to update the buckets

        @logger.warn { "Warning from parsed settings: #{parsed[:warning]}" }  if parsed[:warning]

        parsed
      else
        @logger.debug { "invalid settings: #{settings.inspect}" }
        nil
      end
    end

    def http_span_metadata(kind, attributes)
      return { http: false } unless kind == ::OpenTelemetry::Trace::SpanKind::SERVER &&
        (attributes.key?(ATTR_HTTP_REQUEST_METHOD) || attributes.key?(ATTR_HTTP_METHOD))

      method_ = (attributes[ATTR_HTTP_REQUEST_METHOD] || attributes[ATTR_HTTP_METHOD]).to_s
      status = (attributes[ATTR_HTTP_RESPONSE_STATUS_CODE] || attributes[ATTR_HTTP_STATUS_CODE] || 0).to_i
      scheme = (attributes[ATTR_URL_SCHEME] || attributes[ATTR_HTTP_SCHEME] || "http").to_s
      hostname = (attributes[ATTR_SERVER_ADDRESS] || attributes[ATTR_NET_HOST_NAME] || "localhost").to_s
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

      @logger.debug { "Retrieved http metadata: #{http_metadata.inspect}"}
      http_metadata
    end

    # tested - can run
    def parse_settings(unparsed)
      return unless unparsed.is_a?(Hash)

      return unless unparsed['value'].is_a?(Numeric) &&
                    unparsed['timestamp'].is_a?(Numeric) &&
                    unparsed['ttl'].is_a?(Numeric)

      sample_rate = unparsed['value']
      timestamp = unparsed['timestamp']
      ttl = unparsed['ttl']

      return unless unparsed['flags'].is_a?(String)

      flags = Flags::OK
      flag_map = {
        "OVERRIDE" => ::Flags::OVERRIDE,
        "SAMPLE_START" => ::Flags::SAMPLE_START,
        "SAMPLE_THROUGH_ALWAYS" => ::Flags::SAMPLE_THROUGH_ALWAYS,
        "TRIGGER_TRACE" => ::Flags::TRIGGERED_TRACE,
      }

      flag = nil
      unparsed['flags'].split(',').each { |f| flag = flag_map[f] }
      flags = flag if flag

      buckets = {}
      signature_key = nil

      if unparsed['arguments'].is_a?(Hash)
        args = unparsed['arguments']

        if args['BucketCapacity'].is_a?(Numeric) && args['BucketRate'].is_a?(Numeric)
          buckets[BucketType::DEFAULT] = { capacity: args['BucketCapacity'], rate: args['BucketRate'] }
        end

        if args['TriggerRelaxedBucketCapacity'].is_a?(Numeric) && args['TriggerRelaxedBucketRate'].is_a?(Numeric)
          buckets['trigger_relaxed'] = { capacity: args['TriggerRelaxedBucketCapacity'], rate: args['TriggerRelaxedBucketRate'] }
        end

        if args['TriggerStrictBucketCapacity'].is_a?(Numeric) && args['TriggerStrictBucketRate'].is_a?(Numeric)
          buckets['trigger_strict'] = { capacity: args['TriggerStrictBucketCapacity'], rate: args['TriggerStrictBucketRate'] }
        end

        if args['SignatureKey'].is_a?(String)
          signature_key = args['SignatureKey'].bytes
        end
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
