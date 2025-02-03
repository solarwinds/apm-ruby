# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

class OboeSampler
  SW_KEYS_ATTRIBUTE = "SWKeys"
  PARENT_ID_ATTRIBUTE = "sw.tracestate_parent_id"
  SAMPLE_RATE_ATTRIBUTE = "SampleRate"
  SAMPLE_SOURCE_ATTRIBUTE = "SampleSource"
  BUCKET_CAPACITY_ATTRIBUTE = "BucketCapacity"
  BUCKET_RATE_ATTRIBUTE = "BucketRate"
  TRIGGERED_TRACE_ATTRIBUTE = "TriggeredTrace"

  TRACESTATE_REGEXP = /^[0-9a-f]{16}-[0-9a-f]{2}$/
  BUCKET_INTERVAL = 1000
  DICE_SCALE = 1_000_000

  OTEL_SAMPLING_DECISION = ::OpenTelemetry::SDK::Trace::Samplers::Decision

  def initialize(logger)
    @logger = logger
    @counters = Metrics.new
    @buckets = {
      BucketType::DEFAULT => TokenBucket.new(interval: BUCKET_INTERVAL),
      BucketType::TRIGGER_RELAXED => TokenBucket.new(interval: BUCKET_INTERVAL),
      BucketType::TRIGGER_STRICT => TokenBucket.new(interval: BUCKET_INTERVAL)
    }
    @settings = nil

    @buckets.values.each(&:start)
  end


  # return sampling result
  def should_sample(params)
    context, _, _, _, attributes = params

    parent_span = trace.get_span(context)
    type = SpanType.span_type(parent_span)
    @logger.debug {"span type is #{type}"}

    # For local spans, we always trust the parent
    if type == SpanType::LOCAL
      if parent_span.span_context.trace_flags & TraceFlags::SAMPLED != 0
        return { decision: OTEL_SAMPLING_DECISION::RECORD_AND_SAMPLED }
      else
        return { decision: OTEL_SAMPLING_DECISION::NOT_RECORD }
      end
    end

    sample_state = SampleState.new(decision: OTEL_SAMPLING_DECISION::NOT_RECORD,
                                   attributes: attributes,
                                   params: params,
                                   settings: get_settings(params),
                                   trace_state: parent_span.span_context.trace_state['sw'], # get tracestate with sw=xxxx
                                   headers: request_headers(params))

    counters[:request_count].add(1, {})

    if sample_state.headers["X-Trace-Options"]
      # this parse_trace_options is the function from trace_options file

      sample_state.trace_options = TraceOptions.parse_trace_options(sample_state.headers["X-Trace-Options"], @logger)

      @logger.debug { "X-Trace-Options present: #{sample_state.trace_options}" }

      if sample_state.headers["X-Trace-Options-Signature"]
        @logger.debug { "X-Trace-Options-Signature present; validating" }

        # this validate_signature is the function from trace_options file
        sample_state.trace_options[:response][:auth] = validate_signature(
          sample_state.header["X-Trace-Options"],
          sample_state.header["X-Trace-Options-Signature"],
          sample_state.settings.signature_key,
          sample_state.trace_options[:timestamp]
        )

        # If the request has an invalid signature, we always short circuit
        if sample_state.trace_options[:response][:auth] != Auth::OK # Auth::OK is a string from trace_options.rb: 'ok'
          @logger.debug { "X-Trace-Options-Signature invalid; tracing disabled" }
          handle_response_headers(sample_state)
          return { decision: OTEL_SAMPLING_DECISION::NOT_RECORD }
        end
      end

      unless sample_state.trace_options[:trigger_trace]
        sample_state.trace_options[:response][:trigger_trace] = TriggerTrace::NOT_REQUESTED # TriggerTrace::NOT_REQUESTED is a string from trace_options.rb: 'not-requested'
      end

      # Apply span attributes
      if sample_state.trace_options[:sw_keys]
        sample_state.attributes[SW_KEYS_ATTRIBUTE] = sample_state.trace_options[:sw_keys]
      end

      sample_state.trace_options[:custom].each do |k, v|
        sample_state.attributes[k] = v
      end

      # List ignored keys in response
      if sample_state.trace_options[:ignored].any?
        sample_state.trace_options[:response][:ignored] = sample_state.trace_options[:ignored].map { |k, _| k }
      end
    end

    unless sample_state.settings
      @logger.debug { "settings unavailable; sampling disabled" }

      if sample_state.trace_options.trigger_trace
        @logger.debug { "trigger trace requested but unavailable" }
        sample_state.trace_options[:response][:trigger_trace] = TriggerTrace::SETTINGS_NOT_AVAILABLE # TriggerTrace::NOT_REQUESTED is a string from trace_options.rb
      end

      handle_response_headers(sample_state)
      return { decision: OTEL_SAMPLING_DECISION::NOT_RECORD, attributes: sample_state.attributes }
    end

    # https://swicloud.atlassian.net/wiki/spaces/NIT/pages/3815473156/Tracing+Decision+Tree
    if sample_state.trace_state && TRACESTATE_REGEXP.match?(sample_state.trace_state)

      @logger.debug { "context is valid for parent-based sampling" }
      parent_based_algo(sample_state)

    elsif sample_state.settings.flags & Flags::SAMPLE_START != 0
      if sample_state.trace_options.trigger_trace
        @logger.debug { "trigger trace requested" }
        trigger_trace_algo(sample_state)
      else
        @logger.debug { "defaulting to dice roll" }
        dice_roll_algo(sample_state)
      end
    else
      @logger.debug { "SAMPLE_START is unset; sampling disabled" }
      disabled_algo(sample_state)
    end

    @logger.debug { "final sampling state: #{s}" }

    handle_response_headers(sample_state)

    { decision: sample_state.decision, attributes: sample_state.attributes }
  end

  def parentBasedAlgo(sample_state)
    context = sample_state.params.first

    # compare the parent_id
    sample_state.attributes[PARENT_ID_ATTRIBUTE] = sample_state.trace_state[0, 16]

    if sample_state.trace_options[:trigger_trace] # need to implement trace_options
      @logger.debug { 'trigger trace requested but ignored' }
      sample_state.trace_options[:response][:trigger_trace] = TriggerTrace::IGNORED
    end

    if sample_state.settings.flags & Flags::SAMPLE_THROUGH_ALWAYS != 0
      @logger.debug { 'SAMPLE_THROUGH_ALWAYS is set; parent-based sampling' }

      flags = sample_state.trace_state[-2, 2].to_i(16)
      sampled = flags & OpenTelemetry::Trace::TraceFlags::SAMPLED != 0

      if sampled
        @logger.debug { 'parent is sampled; record and sample' }

        @counters[:trace_count].add(1, {})
        @counters[:through_trace_count].add(1, {}) # ruby metrics only add incremented value and attributes

        sample_state.decision = OTEL_SAMPLING_DECISION::RECORD_AND_SAMPLE
      else
        @logger.debug { 'parent is not sampled; record only' }

        sample_state.decision = OTEL_SAMPLING_DECISION::RECORD_ONLY
      end
    else
      @logger.debug { 'SAMPLE_THROUGH_ALWAYS is unset; sampling disabled' }

      if sample_state.settings.flags & Flags::SAMPLE_START != 0
        @logger.debug { 'SAMPLE_START is set; record' }
        sample_state.decision = OTEL_SAMPLING_DECISION::RECORD_ONLY
      else
        @logger.debug { 'SAMPLE_START is unset; don\'t record' }
        sample_state.decision = OTEL_SAMPLING_DECISION::DROP
      end
    end
  end

  def triggerTraceAlgo(sample_state)

    context = sample_state.params.first

    if sample_state.settings.flags & Flags::TRIGGERED_TRACE != 0
      @logger.debug { "TRIGGERED_TRACE set; trigger tracing" }

      bucket = nil
      # If there's an auth response present, it's a valid signed request
      # Otherwise, this code wouldn't be reached
      if sample_state.trace_options.response.auth
        @logger.debug { "signed request; using relaxed rate" }

        bucket = @buckets[BucketType::TRIGGER_RELAXED]
      else
        @logger.debug { "unsigned request; using strict rate" }

        bucket = @buckets[BucketType::TRIGGER_STRICT]
      end

      sample_state.attributes[TRIGGERED_TRACE_ATTRIBUTE] = true
      sample_state.attributes[BUCKET_CAPACITY_ATTRIBUTE] = bucket.capacity
      sample_state.attributes[BUCKET_RATE_ATTRIBUTE] = bucket.rate

      if bucket.consume
        @logger.debug { "sufficient capacity; record and sample" }

        # this.#counters.triggeredTraceCount.add(1, {}, context) # need to check js counter api
        @counters[:triggered_trace_count].add(1, {})
        @counters[:trace_count].add(1, {})

        sample_state.trace_options.response.trigger_trace = TriggerTrace::OK
        sample_state.decision = OTEL_SAMPLING_DECISION::RECORD_AND_SAMPLE
      else
        @logger.debug { "insufficient capacity; record only" }

        sample_state.trace_options.response.trigger_trace = TriggerTrace::RATE_EXCEEDED
        sample_state.decision = OTEL_SAMPLING_DECISION::RECORD_ONLY
      end
    else
      @logger.debug { "TRIGGERED_TRACE unset; record only" }

      sample_state.trace_options.response.trigger_trace = TriggerTrace::TRIGGER_TRACING_DISABLED
      sample_state.decision = OTEL_SAMPLING_DECISION::RECORD_ONLY
    end
  end


  def diceRollAlgo(sample_state)
    context = sample_state.params.first

    dice = Dice.new(rate: sample_state.settings.sample_rate, scale: DICE_SCALE)
    sample_state.attributes[SAMPLE_RATE_ATTRIBUTE] = dice.rate
    sample_state.attributes[SAMPLE_SOURCE_ATTRIBUTE] = sample_state.settings.sample_source

    @counters[:sample_count].add(1, {})

    if dice.roll
      @logger.debug { "dice roll success; checking capacity" }

      bucket = @buckets[BucketType::DEFAULT]
      sample_state.attributes[BUCKET_CAPACITY_ATTRIBUTE] = bucket.capacity
      sample_state.attributes[BUCKET_RATE_ATTRIBUTE] = bucket.rate

      if bucket.consume
        @logger.debug { "sufficient capacity; record and sample" }

        @counters[:trace_count].add(1, {})

        ssample_state.decision = OTEL_SAMPLING_DECISION::RECORD_AND_SAMPLE
      else
        @logger.debug { "insufficient capacity; record only" }

        @counters[:token_bucket_exhaustion_count].add(1, {})

        ssample_state.decision = OTEL_SAMPLING_DECISION::RECORD_ONLY
      end
    else
      @logger.debug { "dice roll failure; record only" }
      ssample_state.decision = OTEL_SAMPLING_DECISION::RECORD_ONLY
    end
  end

  def disabledAlgo(sample_state)
    if sample_state.trace_options.trigger_trace
      @logger.debug { "trigger trace requested but tracing disabled" }
      sample_state.trace_options.response.trigger_trace = TriggerTrace.TRACING_DISABLED
    end

    if sample_state.settings.flags & Flags.SAMPLE_THROUGH_ALWAYS != 0
      @logger.debug { "SAMPLE_THROUGH_ALWAYS is set; record" }
      sample_state.decision = OTEL_SAMPLING_DECISION::RECORD_ONLY
    else
      @logger.debug { "SAMPLE_THROUGH_ALWAYS is unset; don't record" }
      sample_state.decision = OTEL_SAMPLING_DECISION::DROP
    end
  end

  def update_settings(settings)
    if settings.timestamp > (@settings.timestamp || 0)
      @settings = settings

      @buckets.each do |type, bucket|
        bucket_settings = @settings.buckets[type]
        bucket.update(bucket_settings) if bucket_settings
      end
    end
  end

  # only sampler need to implement this, no need for http_sampler to implement it
  def set_response_headers(headers, *params)
    raise NotImplementedError, "#{self.class} must implement `set_response_headers`"
  end

  def handle_response_headers(sample_state)
    headers = {}
    stringified_trace_options = TraceOptions.stringify_trace_options_response(sample_state.trace_options.response)
    headers["X-Trace-Options-Response"] = stringified_trace_options if sample_state.trace_options.response

    set_response_headers(headers, sample_state.params)
  end

  def get_settings(params)
    return if @settings.nil?

    expiry = (@settings.timestamp + @settings.ttl) * 1000
    if Time.now.to_i * 1000 > expiry
      @logger.debug { "settings expired, removing" }
      @settings = undefined
      return
    end

    return SamplingSettings.merge(@settings, local_settings(params))
  end

  def local_settings(params); end

  def request_headers(params); end

end


