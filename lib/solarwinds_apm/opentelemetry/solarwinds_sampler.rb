# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  module OpenTelemetry
    # SolarWindsSampler
    class SolarWindsSampler
      INTERNAL_BUCKET_CAPACITY   = "BucketCapacity".freeze
      INTERNAL_BUCKET_RATE       = "BucketRate".freeze
      INTERNAL_SAMPLE_RATE       = "SampleRate".freeze
      INTERNAL_SAMPLE_SOURCE     = "SampleSource".freeze
      INTERNAL_SW_KEYS           = "SWKeys".freeze
      LIBOBOE_CONTINUED          = -1
      SW_TRACESTATE_CAPTURE_KEY  = "sw.w3c.tracestate".freeze
      SW_TRACESTATE_ROOT_KEY     = "sw.tracestate_parent_id".freeze
      UNSET                      = -1
      SWO_TRACING_ENABLED        = 1
      SWO_TRACING_DISABLED       = 0
      SWO_TRACING_UNSET          = -1
      XTRACEOPTIONS_RESP_AUTH    = "auth".freeze
      XTRACEOPTIONS_RESP_IGNORED = "ignored".freeze
      XTRACEOPTIONS_RESP_TRIGGER_IGNORED       = "ignored".freeze
      XTRACEOPTIONS_RESP_TRIGGER_NOT_REQUESTED = "not-requested".freeze
      XTRACEOPTIONS_RESP_TRIGGER_TRACE         = "trigger-trace".freeze

      attr_reader :description

      def initialize(config={})
        @config = config
      end

      def ==(other)
        @decision == other.decision && @description == other.description
      end

      # @api private
      #
      # See {Samplers}.
      # trace_id
      # parent_context: OpenTelemetry::Context
      def should_sample?(trace_id:, parent_context:, links:, name:, kind:, attributes:)

        SolarWindsAPM.logger.debug do 
          "[#{self.class}/#{__method__}] should_sample? start parameters \n
                                        trace_id: #{trace_id.unpack1('H*')}\n
                                        parent_context:  #{parent_context}\n
                                        parent_context.inspect:  #{parent_context.inspect}\n
                                        links: #{links}\n
                                        name: #{name}\n
                                        kind: #{kind}\n
                                        attributes: #{attributes}"
        end

        parent_span_context = ::OpenTelemetry::Trace.current_span(parent_context).context        
        xtraceoptions       = ::SolarWindsAPM::XTraceOptions.new(parent_context)
        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] parent_span_context: #{parent_span_context.inspect}\n xtraceoptions: #{xtraceoptions.inspect}"}

        liboboe_decision    = calculate_liboboe_decision(parent_span_context, xtraceoptions, name, kind, attributes)
        otel_decision       = otel_decision_from_liboboe(liboboe_decision)
        new_trace_state     = calculate_trace_state(liboboe_decision, parent_span_context, xtraceoptions)
        new_attributes      = otel_sampled?(otel_decision)? calculate_attributes(attributes, liboboe_decision, new_trace_state, parent_span_context, xtraceoptions) : nil
        sampling_result     = ::OpenTelemetry::SDK::Trace::Samplers::Result.new(decision: otel_decision, 
                                                                                attributes: new_attributes, 
                                                                                tracestate: new_trace_state)
        
        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] should_sample? end with sampling_result: #{sampling_result.inspect} from otel_decision: #{otel_decision.inspect} and new_attributes: #{new_attributes.inspect}"}
        sampling_result
      rescue StandardError => e
        SolarWindsAPM.logger.info {"[#{self.class}/#{__method__}] sampler error: #{e.message}"}
        ::OpenTelemetry::SDK::Trace::Samplers::Result.new(decision: ::OpenTelemetry::SDK::Trace::Samplers::Decision::DROP, 
                                                          attributes: attributes, 
                                                          tracestate: ::OpenTelemetry::Trace::Tracestate::DEFAULT)
      end

      protected

      attr_reader :decision

      private

      ##
      # use parent_span_context and xtraceoptions object to feed to liboboe function getDecisions that get liboboe_decision
      # name, kind and attributes are used for transaction filter caching (to avoid continous calculate_trace_mode calculation)
      # return decision Hash
      def calculate_liboboe_decision(parent_span_context, xtraceoptions, name, kind, attributes)
        tracestring = Utils.traceparent_from_context(parent_span_context) if parent_span_context.valid? && parent_span_context.remote?
        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] tracestring: #{tracestring}"}

        # otel-ruby contrib use different key to store url info, currently it's using http.target for path
        url_path = attributes.nil?? '' : attributes['http.target']
        transaction_naming_key = "#{url_path}-#{name}-#{kind}"
        tracing_mode           = SolarWindsAPM::TransactionCache.get(transaction_naming_key)
        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] transaction cache: #{transaction_naming_key}; tracing_mode: #{tracing_mode}."}

        unless tracing_mode
          trans_settings = SolarWindsAPM::TransactionSettings.new(url_path: url_path, name: name, kind: kind)          
          tracing_mode   = trans_settings.calculate_trace_mode == 1 ? SWO_TRACING_ENABLED : SWO_TRACING_DISABLED
          SolarWindsAPM::TransactionCache.set(transaction_naming_key, tracing_mode)
        end

        sw_member_value    = parent_span_context.tracestate[SolarWindsAPM::Constants::INTL_SWO_TRACESTATE_KEY]
        trigger_trace_mode = OboeTracingMode.get_oboe_trigger_trace_mode(@config["trigger_trace"])
        sample_rate        = UNSET
        options            = xtraceoptions&.options
        trigger_trace      = xtraceoptions&.intify_trigger_trace || 0
        signature          = xtraceoptions&.signature
        timestamp          = xtraceoptions&.timestamp

        SolarWindsAPM.logger.debug do 
          "[#{self.class}/#{__method__}] get liboboe decision parameters: \n
                                         tracestring: #{tracestring}\n
                                         sw_member_value: #{sw_member_value}\n
                                         tracing_mode:    #{tracing_mode}\n
                                         sample_rate:     #{sample_rate}\n
                                         trigger_trace:   #{trigger_trace}\n
                                         trigger_trace_mode:    #{trigger_trace_mode}\n
                                         options:      #{options}\n
                                         signature:    #{signature}\n
                                         timestamp:    #{timestamp}"
        end

        args = [tracestring, sw_member_value, tracing_mode, sample_rate,
                trigger_trace, trigger_trace_mode, options, signature,timestamp]

        do_metrics, do_sample, rate, source, bucket_rate,
          bucket_cap, decision_type, auth, status_msg, auth_msg,
            status = SolarWindsAPM::Context.getDecisions(*args)

        decision = {}
        decision["do_metrics"]    = do_metrics > 0
        decision["do_sample"]     = do_sample > 0 
        decision["rate"]          = rate
        decision["source"]        = source
        decision["bucket_rate"]   = bucket_rate
        decision["bucket_cap"]    = bucket_cap
        decision["decision_type"] = decision_type
        decision["auth"]          = auth
        decision["status_msg"]    = status_msg
        decision["auth_msg"]      = auth_msg
        decision["status"]        = status
        decision
      end

      def otel_decision_from_liboboe(liboboe_decision)

        decision = ::OpenTelemetry::SDK::Trace::Samplers::Decision::DROP
        if liboboe_decision["do_sample"]
          decision = ::OpenTelemetry::SDK::Trace::Samplers::Decision::RECORD_AND_SAMPLE  # even if not do_metrics
        elsif liboboe_decision["do_metrics"]
          decision = ::OpenTelemetry::SDK::Trace::Samplers::Decision::RECORD_ONLY
        end
        SolarWindsAPM.logger.debug {"otel decision: #{decision} created from liboboe_decision: #{liboboe_decision}"}
        decision
      end

      ##
      # add sw=value and xtrace_options_response=value into the old/new tracestate 
      # the returned value tracestate will be used in propagating to next services
      def calculate_trace_state(liboboe_decision, parent_span_context, xtraceoptions)
        if !parent_span_context.valid?
          trace_state = create_new_trace_state(parent_span_context, liboboe_decision)
        elsif parent_span_context.tracestate.nil?
          trace_state = create_new_trace_state(parent_span_context, liboboe_decision)
        else
          trace_state = parent_span_context.tracestate.set_value(SolarWindsAPM::Constants::INTL_SWO_TRACESTATE_KEY, 
                                                                 sw_from_span_and_decision(parent_span_context, liboboe_decision))
          SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] updated trace_state:  #{trace_state.inspect}"}
        end

        # for setting up the xtrace_options_response
        if xtraceoptions&.options
          trace_state = trace_state.set_value(XTraceOptions.sw_xtraceoptions_response_key.to_s, 
                                              create_xtraceoptions_response_value(liboboe_decision, parent_span_context, xtraceoptions)) 
        end
        trace_state
      end

      ##
      # 
      def create_new_trace_state(parent_span_context, liboboe_decision)
        decision = sw_from_span_and_decision(parent_span_context, liboboe_decision)
        trace_state = ::OpenTelemetry::Trace::Tracestate.from_hash({SolarWindsAPM::Constants::INTL_SWO_TRACESTATE_KEY => decision}) # e.g. sw=3e222c863a04123a-01
        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] created new trace_state: #{trace_state.inspect}"}
        trace_state
      end

      ##
      #
      def create_xtraceoptions_response_value(liboboe_decision, parent_span_context, xtraceoptions)

        response = []
        w3c_sanitized = SolarWindsAPM::Constants::INTL_SWO_EQUALS_W3C_SANITIZED
        w3c_sanitized_comma = SolarWindsAPM::Constants::INTL_SWO_COMMA_W3C_SANITIZED
        response << [XTRACEOPTIONS_RESP_AUTH, liboboe_decision['auth_msg']].join(w3c_sanitized) if xtraceoptions.signature && liboboe_decision['auth_msg']
        
        if !liboboe_decision["auth"] || liboboe_decision["auth"] < 1
          if xtraceoptions.trigger_trace
            # If a traceparent header was provided then oboe does not generate the message
            tracestring = Utils.traceparent_from_context(parent_span_context) if parent_span_context.valid? && parent_span_context.remote?  
            trigger_msg = tracestring && liboboe_decision['decision_type'] == 0 ? XTRACEOPTIONS_RESP_TRIGGER_IGNORED : liboboe_decision['status_msg']
            SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] tracestring: #{tracestring}; trigger_msg: #{trigger_msg}"}
          else
            trigger_msg = XTRACEOPTIONS_RESP_TRIGGER_NOT_REQUESTED
          end

          response << [XTRACEOPTIONS_RESP_TRIGGER_TRACE, trigger_msg].join(w3c_sanitized) # e.g. response << trigger-trace####ok
        end

        # appending ignored value from xtraceoptions to response. e.g. response << ignored####invalidkeys,invalidkeys,invalidkeys
        response << [XTRACEOPTIONS_RESP_IGNORED, xtraceoptions.ignored.join(w3c_sanitized_comma)].join(w3c_sanitized) unless xtraceoptions.ignored.empty?
        joined_response = response.join(';')
        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] final response_value: #{joined_response}"}
        joined_response
      end

      ##
      # calculate_attributes is used for getting the otel Result class in last step of sampler should_sample? 
      # e.g. result = Result.new(decision: otel_decision, attributes: new_attributes, tracestate: new_trace_state)
      # calculate_attributes use new_trace_state that is derived from current span information and old tracestate from parent_span_context.tracestate
      # the sw.w3c.tracestate should perserve the old tracestate value for debugging purpose
      def calculate_attributes(attributes, liboboe_decision, trace_state, parent_span_context, xtraceoptions)
        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] new_trace_state: #{trace_state.inspect}"}
        new_attributes = attributes.dup || {}

        # Always (root or is_remote) set _INTERNAL_SW_KEYS if injected
        new_attributes[INTERNAL_SW_KEYS] = xtraceoptions.sw_keys if xtraceoptions.sw_keys

        # Always (root or is_remote) set custom KVs if extracted from x-trace-options
        xtraceoptions.custom_kvs&.each {|k,v| new_attributes[k] = v}

        # Always (root or is_remote) set service entry internal KVs       
        new_attributes[INTERNAL_BUCKET_CAPACITY] = liboboe_decision["bucket_cap"].to_s
        new_attributes[INTERNAL_BUCKET_RATE]     = liboboe_decision["bucket_rate"].to_s
        new_attributes[INTERNAL_SAMPLE_RATE]     = liboboe_decision["rate"]
        new_attributes[INTERNAL_SAMPLE_SOURCE]   = liboboe_decision["source"]

        # set sw.tracestate_parent_id if its tracestate contains "sw"
        sw_value = parent_span_context.tracestate.value(SolarWindsAPM::Constants::INTL_SWO_TRACESTATE_KEY)
        new_attributes[SW_TRACESTATE_ROOT_KEY] =  sw_value.split("-")[0] if sw_value && parent_span_context.remote?

        # If unsigned or signed TT (root or is_remote), set TriggeredTrace
        new_attributes[SolarWindsAPM::Constants::INTERNAL_TRIGGERED_TRACE] = true if xtraceoptions.trigger_trace

        # Trace's root span has no valid traceparent nor tracestate so we can't calculate remaining attributes
        if !parent_span_context.valid? || trace_state.nil?
          SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] No valid traceparent or no tracestate - returning attributes: #{new_attributes}"}
          return new_attributes.freeze || nil
        end

        new_attributes = add_tracestate_capture_to_new_attributes(new_attributes, liboboe_decision, trace_state, parent_span_context)
        new_attributes.freeze
      end

      ##
      # 
      def add_tracestate_capture_to_new_attributes(new_attributes, liboboe_decision, trace_state, parent_span_context)
        
        tracestate_capture = new_attributes[SW_TRACESTATE_CAPTURE_KEY]
        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] tracestate_capture #{tracestate_capture.inspect}; new_attributes #{new_attributes.inspect}"}

        if tracestate_capture.nil?
          trace_state_no_response = trace_state.delete(XTraceOptions.sw_xtraceoptions_response_key)
        else 
          # retain all potential tracestate pairs for attributes and generate new sw=key for tracestate based on root parent_span_id
          attr_trace_state        = ::OpenTelemetry::Trace::Tracestate.from_string(tracestate_capture)
          new_attr_trace_state    = attr_trace_state.set_value(SolarWindsAPM::Constants::INTL_SWO_TRACESTATE_KEY, sw_from_span_and_decision(parent_span_context,liboboe_decision))
          trace_state_no_response = new_attr_trace_state.delete(XTraceOptions.sw_xtraceoptions_response_key)
        end
        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] trace_state_no_response #{trace_state_no_response.inspect}"}

        trace_state_no_response = parent_span_context.tracestate.delete(XTraceOptions.sw_xtraceoptions_response_key)
        no_sw_count             = trace_state_no_response.to_h.reject { |k, _v| k == "sw" }.count
        new_attributes[SW_TRACESTATE_CAPTURE_KEY] = Utils.trace_state_header(trace_state_no_response) if no_sw_count > 0 
        SolarWindsAPM.logger.debug {"[#{self.class}/#{__method__}] new_attributes after add_tracestate_capture_to_new_attributes: #{new_attributes.inspect}"}
        
        new_attributes
      end

      # formats tracestate sw value from span_id and liboboe decision as 16-byte span_id with 8-bit trace_flags e.g. 1a2b3c4d5e6f7g8h-01
      def sw_from_span_and_decision(parent_span_context, liboboe_decision)
        trace_flag = (liboboe_decision["do_sample"] == true) ? "01" : "00"
        [parent_span_context.hex_span_id, trace_flag].join("-")
      end

      def otel_sampled?(otel_decision)
        otel_decision == ::OpenTelemetry::SDK::Trace::Samplers::Decision::RECORD_AND_SAMPLE
      end
    end
  end
end