# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  class TraceOptions

    TRIGGER_TRACE_KEY = "trigger-trace"
    TIMESTAMP_KEY = "ts"
    SW_KEYS_KEY = "sw-keys"

    CUSTOM_KEY_REGEX = /^custom-[^\s]*$/

    def self.parse_trace_options(header, logger)
      trace_options = TriggerTraceOptions.new(nil,nil,nil,{},[], TraceOptionsResponse.new(nil,nil,[]))

      kvs = header.split(";").map { |kv| k, *vs = kv.split("=").map(&:strip); [k, vs.any? ? vs.join("=") : nil] }
                  .filter { |k, _| !(k.nil? || k.empty?) }
      kvs.each do |k, v|
        case k
        when TRIGGER_TRACE_KEY
          if v || trace_options.trigger_trace
            logger.debug { "invalid trace option for trigger trace" }
            trace_options.ignored << [k, v]
            next
          end
          trace_options.trigger_trace = true
        when TIMESTAMP_KEY
          if v.nil? || trace_options.timestamp
            logger.debug { "invalid trace option for timestamp" }
            trace_options.ignored << [k, v]
            next
          end

          unless numeric_integer?(v)
            logger.debug { "invalid trace option for timestamp, should be an integer" }
            trace_options.ignored << [k, v]
            next
          end
          trace_options.timestamp = v.to_i
        when SW_KEYS_KEY
          if v.nil? || trace_options.sw_keys
            logger.debug { "invalid trace option for sw keys" }
            trace_options.ignored << [k, v]
            next
          end
          trace_options.sw_keys = v
        when CUSTOM_KEY_REGEX
          if v.nil? || trace_options.custom[k]
            logger.debug { "invalid trace option for custom key #{k}" }
            trace_options.ignored << [k, v]
            next
          end
          trace_options.custom[k] = v
        else
          trace_options.ignored << [k, v]
        end
      end

      trace_options
    end

    def self.numeric_integer?(str)
      true if Integer(str) rescue false
    end

    # combine the array to string separate by ;
    # tracestate doesn't accept value with k=v, here we use k:v
    # but it will be replaced with = when inject in respond header
    def self.stringify_trace_options_response(trace_options_response)
      return if trace_options_response.nil?

      kvs = {
        auth: trace_options_response.auth,
        "trigger-trace": trace_options_response.trigger_trace,
        ignored: trace_options_response.ignored.empty? ? nil : trace_options_response.ignored.join(","),
      }
      kvs.compact.map { |k, v| "#{k}:#{v}" }.join(";")
    end

    def self.validate_signature(header, signature, key, timestamp)
      return Auth::NO_SIGNATURE_KEY unless key
      return Auth::BAD_TIMESTAMP unless timestamp && (Time.now.to_i - timestamp).abs <= 5 * 60

      digest = OpenSSL::HMAC.hexdigest("SHA1", key, header)
      signature == digest ? Auth::OK : Auth::BAD_SIGNATURE
    end
  end
end
