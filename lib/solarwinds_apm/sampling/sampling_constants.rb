# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  TriggerTraceOptions = Struct.new(
    :trigger_trace,
    :timestamp,
    :sw_keys,
    :custom,      # Hash
    :ignored,     # Array
    :response     # TraceOptionsResponse
  )

  TraceOptionsResponse = Struct.new(
    :auth,           # Auth
    :trigger_trace,  # TriggerTrace
    :ignored         # Array
  )

  module Auth
    OK = 'ok'
    BAD_TIMESTAMP = 'bad-timestamp'
    BAD_SIGNATURE = 'bad-signature'
    NO_SIGNATURE_KEY = 'no-signature-key'
  end

  module TriggerTrace
    OK = 'ok'
    NOT_REQUESTED = 'not-requested'
    IGNORED = 'ignored'
    TRACING_DISABLED = 'tracing-disabled'
    TRIGGER_TRACING_DISABLED = 'trigger-tracing-disabled'
    RATE_EXCEEDED = 'rate-exceeded'
    SETTINGS_NOT_AVAILABLE = 'settings-not-available'
  end

  Settings = Struct.new(:sample_rate,
                        :sample_source,
                        :flags,
                        :buckets,           # BucketSettings
                        :signature_key,
                        :timestamp,
                        :ttl)

  LocalSettings = Struct.new(:tracing_mode, # TracingMode
                             :trigger_mode) # {:enabled, :disabled}

  BucketSettings = Struct.new(:capacity, # Number
                              :rate) # Number

  TokenBucketSettings = Struct.new(:capacity,    # Number
                                   :rate,        # Number
                                   :interval) # Number

  module SampleSource
    LOCAL_DEFAULT = 2
    REMOTE = 6
  end

  module Flags
    OK = 0x0
    INVALID = 0x1
    OVERRIDE = 0x2
    SAMPLE_START = 0x4
    SAMPLE_THROUGH_ALWAYS = 0x10
    TRIGGERED_TRACE = 0x20
  end

  module TracingMode
    ALWAYS = Flags::SAMPLE_START | Flags::SAMPLE_THROUGH_ALWAYS
    NEVER = 0x0
  end

  module BucketType
    DEFAULT = ''
    TRIGGER_RELAXED = 'trigger_relaxed'
    TRIGGER_STRICT = 'trigger_strict'
  end

  module SpanType
    ROOT = 'root'
    ENTRY = 'entry'
    LOCAL = 'local'

    VALID_TRACEID_REGEX = /^[0-9a-f]{32}$/i
    VALID_SPANID_REGEX = /^[0-9a-f]{16}$/i

    INVALID_SPANID = '0000000000000000'
    INVALID_TRACEID = '00000000000000000000000000000000'

    def self.span_type(parent_span)
      parent_span_context = parent_span&.context
      if parent_span_context.nil? || !span_context_valid?(parent_span_context)
        ROOT
      elsif parent_span_context.remote?
        ENTRY
      else
        LOCAL
      end
    end

    def self.valid_trace_id?(trace_id)
      VALID_TRACEID_REGEX.match?(trace_id) && trace_id != INVALID_TRACEID
    end

    def self.valid_span_id?(span_id)
      VALID_SPANID_REGEX.match?(span_id) && span_id != INVALID_SPANID
    end

    def self.span_context_valid?(span_context)
      valid_trace_id?(span_context.hex_trace_id) && valid_span_id?(span_context.hex_span_id)
    end
  end

  SampleState = Struct.new(:decision,     # SamplingDecision
                           :attributes,   # Attributes
                           :params,       # SampleParams
                           :settings,     # Settings
                           :trace_state, # String
                           :headers, # RequestHeaders
                           :trace_options) # TraceOptions & { response: TraceOptionsResponse })
end
