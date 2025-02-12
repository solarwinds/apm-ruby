# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

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
    @tracing_mode = config[:tracing_mode] ? :always : :never if config.key?(:tracing_mode)
    @trigger_mode = config[:trigger_trace_enabled]
    @transaction_settings = config[:transaction_settings]
    @ready = false
    @header_storage = nil
  end

  # I don't think we need wait_until_ready when fetching the setting directly from http
  def wait_until_ready(timeout)
    true
  end

  def local_settings(_context, _trace_id, span_name, span_kind, attributes, _links)
    # This settings should use struct LocalSettings
    settings = { tracing_mode: @tracing_mode, trigger_mode: @trigger_mode }
    return settings if @transaction_settings.nil? || @transaction_settings.empty?
    
    http_metadata = http_span_metadata(span_kind, attributes)
    identifier = http_metadata[:http] ? http_metadata[:url] : "#{span_kind}:#{span_name}"
    
    # matcher is transaction regex
    @transaction_settings.each do |setting|
      if setting[:matcher].call(identifier)
        settings[:tracing_mode] = setting[:tracing] ? :always : :never
        break
      end
    end
    settings
  end

  def request_headers(context)
    @header_storage[context].fetch(:request, {})
  end

  def set_response_headers(headers, context)
    storage = @header_storage[context]
    storage[:response].merge!(headers) if storage
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
    return { http: false } unless kind == SpanKind.server &&
      (attributes.key?(ATTR_HTTP_REQUEST_METHOD) || attributes.key?(ATTR_HTTP_METHOD))

    method_ = (attributes[ATTR_HTTP_REQUEST_METHOD] || attributes[ATTR_HTTP_METHOD]).to_s
    status = (attributes[ATTR_HTTP_RESPONSE_STATUS_CODE] || attributes[ATTR_HTTP_STATUS_CODE] || 0).to_i
    scheme = (attributes[ATTR_URL_SCHEME] || attributes[ATTR_HTTP_SCHEME] || "http").to_s
    hostname = (attributes[ATTR_SERVER_ADDRESS] || attributes[ATTR_NET_HOST_NAME] || "localhost").to_s
    path = (attributes[ATTR_URL_PATH] || attributes[ATTR_HTTP_TARGET]).to_s
    url = "#{scheme}://#{hostname}#{path}"

    {
      http: true,
      method: method_,
      status: status,
      scheme: scheme,
      hostname: hostname,
      path: path,
      url: url
    }
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
      "OVERRIDE" => :override,
      "SAMPLE_START" => :sample_start,
      "SAMPLE_THROUGH_ALWAYS" => :sample_through_always,
      "TRIGGER_TRACE" => :triggered_trace
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
      sample_source: :remote,
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
