# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  class TraceOptions
    TRIGGER_TRACE_KEY = 'trigger-trace'
    TIMESTAMP_KEY     = 'ts'
    SW_KEYS_KEY       = 'sw-keys'
    CUSTOM_KEY_REGEX  = /^custom-[^\s]*$/

    def self.parse_trace_options(header, logger)
      logger.debug { "[#{self.class}/#{__method__}] Parsing trace options header: #{header&.slice(0, 100)}..." }
      trace_options = TriggerTraceOptions.new(nil, nil, nil, {}, [], TraceOptionsResponse.new(nil, nil, []))

      kvs = header.split(';').filter_map do |kv|
        key, *values = kv.split('=').map(&:strip)
        next if key.nil? || key.empty?

        value = values.any? ? values.join('=') : nil
        [key, value]
      end

      logger.debug { "[#{self.class}/#{__method__}] Parsed kvs #{kvs.inspect}" }

      kvs.each do |k, v|
        case k
        when TRIGGER_TRACE_KEY
          if v || trace_options.trigger_trace
            logger.debug { "[#{self.class}/#{__method__}] invalid trace option for trigger trace: value=#{v}, already_set=#{trace_options.trigger_trace}" }
            trace_options.ignored << [k, v]
            next
          end
          trace_options.trigger_trace = true
        when TIMESTAMP_KEY
          if v.nil? || trace_options.timestamp
            logger.debug { "[#{self.class}/#{__method__}] invalid trace option for timestamp: value=#{v}, already_set=#{trace_options.timestamp}" }
            trace_options.ignored << [k, v]
            next
          end

          unless numeric_integer?(v)
            logger.debug { "[#{self.class}/#{__method__}] invalid trace option for timestamp, should be an integer: #{v}" }
            trace_options.ignored << [k, v]
            next
          end
          trace_options.timestamp = v.to_i
        when SW_KEYS_KEY
          if v.nil? || trace_options.sw_keys
            logger.debug { "[#{self.class}/#{__method__}] invalid trace option for sw keys: value=#{v}, already_set=#{trace_options.sw_keys}" }
            trace_options.ignored << [k, v]
            next
          end
          trace_options.sw_keys = v
        when CUSTOM_KEY_REGEX
          if v.nil? || trace_options.custom[k]
            logger.debug { "[#{self.class}/#{__method__}] invalid trace option for custom key #{k}: value=#{v}, already_set=#{trace_options.custom[k]}" }
            trace_options.ignored << [k, v]
            next
          end
          trace_options.custom[k] = v
        else
          logger.debug { "[#{self.class}/#{__method__}] Unknown key ignored: #{k}=#{v}" }
          trace_options.ignored << [k, v]
        end
      end
      logger.debug { "[#{self.class}/#{__method__}] Parsing complete: trigger_trace=#{trace_options.trigger_trace}, timestamp=#{trace_options.timestamp}, sw_keys=#{trace_options.sw_keys}, custom_keys=#{trace_options.custom}, ignored=#{trace_options.ignored}" }
      trace_options
    end

    def self.numeric_integer?(str)
      true if Integer(str)
    rescue StandardError
      false
    end

    # combine the array to string separate by ;
    # tracestate doesn't accept value with k=v, here we use k:v
    # but it will be replaced with = when inject in respond header
    def self.stringify_trace_options_response(trace_options_response)
      return if trace_options_response.nil?

      kvs = {
        auth: trace_options_response.auth,
        'trigger-trace': trace_options_response.trigger_trace,
        ignored: trace_options_response.ignored.empty? ? nil : trace_options_response.ignored.join(',')
      }

      kvs.compact!
      result = kvs.map { |k, v| "#{k}:#{v}" }.join(';')
      SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] Stringified trace options response: #{result}" }
      result
    end

    def self.validate_signature(header, signature, key, timestamp)
      unless key
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] Signature validation failed: no signature key available" }
        return Auth::NO_SIGNATURE_KEY
      end

      unless timestamp && (Time.now.to_i - timestamp).abs <= 5 * 60
        SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] Signature validation failed: bad timestamp (diff more than 300s)" }
        return Auth::BAD_TIMESTAMP
      end

      digest = OpenSSL::HMAC.hexdigest('SHA1', key, header)
      is_valid = signature == digest

      SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] Signature validation result: #{is_valid ? 'valid' : 'invalid'}" }
      is_valid ? Auth::OK : Auth::BAD_SIGNATURE
    end
  end
end
