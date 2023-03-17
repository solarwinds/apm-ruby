module SolarWindsOTelAPM
  module OpenTelemetry
    class SolarWindsSampler

      INTERNAL_BUCKET_CAPACITY = "BucketCapacity"
      INTERNAL_BUCKET_RATE = "BucketRate"
      INTERNAL_SAMPLE_RATE = "SampleRate"
      INTERNAL_SAMPLE_SOURCE = "SampleSource"
      INTERNAL_SW_KEYS = "SWKeys"
      LIBOBOE_CONTINUED = -1
      SW_TRACESTATE_CAPTURE_KEY = "sw.w3c.tracestate"
      SW_TRACESTATE_ROOT_KEY = "sw.tracestate_parent_id"
      UNSET = -1
      XTRACEOPTIONS_RESP_AUTH = "auth"
      XTRACEOPTIONS_RESP_IGNORED = "ignored"
      XTRACEOPTIONS_RESP_TRIGGER_IGNORED = "ignored"
      XTRACEOPTIONS_RESP_TRIGGER_NOT_REQUESTED = "not-requested"
      XTRACEOPTIONS_RESP_TRIGGER_TRACE = "trigger-trace"

      attr_reader :description

      def initialize(config={})
        @config = config
        @context = init_context
      end

      def get_description
        "SolarWinds custom opentelemetry sampler"
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

        SolarWindsOTelAPM.logger.debug "####### should_sample? parameters \n
                                        trace_id: #{trace_id.unpack1("H*")}\n
                                        parent_context:  #{parent_context}\n
                                        parent_context.inspect:  #{parent_context.inspect}\n
                                        links: #{links}\n
                                        name: #{name}\n
                                        kind: #{kind}\n
                                        attributes: #{attributes}"

        # if the upstream has tracestate: sw=.... then it should capture it 

        parent_span_context = ::OpenTelemetry::Trace.current_span(parent_context).context
        SolarWindsOTelAPM.logger.debug "####### should_sample? parent_span_context: #{parent_span_context.inspect}"
        
        xtraceoptions       = SolarWindsOTelAPM::XTraceOptions.new(parent_context)
        SolarWindsOTelAPM.logger.debug "####### xtraceoptions: #{xtraceoptions.inspect}"
        
        liboboe_decision    = calculate_liboboe_decision(parent_span_context, xtraceoptions)
        SolarWindsOTelAPM.logger.debug "####### liboboe_decision: #{liboboe_decision.inspect}"

        otel_decision   = otel_decision_from_liboboe(liboboe_decision)
        SolarWindsOTelAPM.logger.debug "####### otel_decision: #{otel_decision.inspect}"

        new_trace_state = calculate_trace_state(liboboe_decision,parent_span_context,xtraceoptions)
        SolarWindsOTelAPM.logger.debug "####### new_trace_state: #{new_trace_state.inspect}"

        new_attributes  = calculate_attributes(name,attributes,liboboe_decision,new_trace_state,parent_span_context,xtraceoptions)
        SolarWindsOTelAPM.logger.debug "####### new_attributes: #{new_attributes.inspect}"
        sampling_result = ::OpenTelemetry::SDK::Trace::Samplers::Result.new(decision: otel_decision, attributes: new_attributes, tracestate: new_trace_state)
        SolarWindsOTelAPM.logger.debug "####### sampling_result: #{sampling_result.inspect}"

        return sampling_result
      end

      protected

      attr_reader :decision

      private

      def init_context
        context = (SolarWindsOTelAPM.loaded == true)? SolarWindsOTelAPM::Context : nil
      end

      # return Hash
      def calculate_liboboe_decision(parent_span_context, xtraceoptions)

        tracestring = nil
        if parent_span_context.valid? && parent_span_context.remote?
          tracestring = Transformer.traceparent_from_context(parent_span_context)
          SolarWindsOTelAPM.logger.debug "####### calculate_liboboe_decision parent_span_context.remote? #{parent_span_context.remote?} with #{tracestring}"
        end

        sw_member_value = parent_span_context.tracestate[SolarWindsOTelAPM::Constants::INTL_SWO_TRACESTATE_KEY]
        tracing_mode = UNSET

        # need to create the config class
        trigger_trace_mode = OboeTracingMode.get_oboe_trigger_trace_mode(@config["trigger_trace"])
        sample_rate = UNSET

        options = nil
        trigger_trace = 0
        signature = nil
        timestamp = nil
        if xtraceoptions
          options = xtraceoptions.options
          trigger_trace = xtraceoptions.intify_trigger_trace
          signature = xtraceoptions.signature
          timestamp = xtraceoptions.timestamp
        end

        SolarWindsOTelAPM.logger.debug "####### decision parameters \n
                                         tracestring: #{tracestring}\n
                                         sw_member_value: #{sw_member_value}\n
                                         tracing_mode:    #{tracing_mode}\n
                                         sample_rate:     #{sample_rate}\n
                                         trigger_trace:   #{trigger_trace}\n
                                         trigger_trace_mode:    #{trigger_trace_mode}\n
                                         options:      #{options}\n
                                         signature:    #{signature}\n
                                         timestamp:    #{timestamp}"

        args = [tracestring,sw_member_value,tracing_mode,sample_rate,trigger_trace,trigger_trace_mode,options,signature,timestamp] 
        do_metrics, do_sample, rate, source, bucket_rate, \
            bucket_cap, decision_type, auth, status_msg, auth_msg, status = SolarWindsOTelAPM::Context.getDecisions(*args)

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
        return decision
      end


      def otel_decision_from_liboboe(liboboe_decision)

        decision = ::OpenTelemetry::SDK::Trace::Samplers::Decision::DROP
        if liboboe_decision["do_sample"]
          decision = ::OpenTelemetry::SDK::Trace::Samplers::Decision::RECORD_AND_SAMPLE  # even if not do_metrics
        elsif liboboe_decision["do_metrics"]
          decision = ::OpenTelemetry::SDK::Trace::Samplers::Decision::RECORD_ONLY
        end
        SolarWindsOTelAPM.logger.debug "OTel decision created: #{decision}"
        return decision

      end

      def create_xtraceoptions_response_value(decision, parent_span_context, xtraceoptions)

        response = Array.new

        SolarWindsOTelAPM.logger.debug  "####### create_xtraceoptions_response_value decision[auth]: #{decision["auth"]}; decision[auth_msg]: #{decision["auth_msg"]}; xtraceoptions.trigger_trace: #{xtraceoptions.trigger_trace}"

        if xtraceoptions.signature && decision["auth_msg"]
          response << [XTRACEOPTIONS_RESP_AUTH, decision["auth_msg"]].join(SolarWindsOTelAPM::Constants::INTL_SWO_EQUALS_W3C_SANITIZED)
        end

        if !decision["auth"] || decision["auth"] < 1
          trigger_msg = ""
          tracestring = nil
          if xtraceoptions.trigger_trace
            # If a traceparent header was provided then oboe does not generate the message
            tracestring = Transformer.traceparent_from_context(parent_span_context) if parent_span_context.valid? && parent_span_context.remote?  
            trigger_msg = (tracestring && decision["decision_type"] == 0)? XTRACEOPTIONS_RESP_TRIGGER_IGNORED : decision["status_msg"]
          else
            trigger_msg = XTRACEOPTIONS_RESP_TRIGGER_NOT_REQUESTED
          end

          SolarWindsOTelAPM.logger.debug "####### create_xtraceoptions_response_value parent_span_context: #{parent_span_context}; tracestring: #{tracestring}; trigger_msg: #{trigger_msg}"

          # e.g. response << trigger-trace####ok
          response << [XTRACEOPTIONS_RESP_TRIGGER_TRACE, trigger_msg].join(SolarWindsOTelAPM::Constants::INTL_SWO_EQUALS_W3C_SANITIZED)

        end

        # so far the x-trace-options are only used for liboboe calculate decision for x-trace feature
        # probably not need for remaining services since liboboe decision only calculate once
        if xtraceoptions.ignored
          if xtraceoptions.ignored.size != 0
            ignored_response = [XTRACEOPTIONS_RESP_IGNORED, xtraceoptions.ignored.join(SolarWindsOTelAPM::Constants::INTL_SWO_COMMA_W3C_SANITIZED)]
            response << ignored_response.join(SolarWindsOTelAPM::Constants::INTL_SWO_EQUALS_W3C_SANITIZED)
            # e.g. response << ignored####invalidkeys,invalidkeys,invalidkeys
          end
        end 

        response.join(";")  # e.g. trigger-trace####ok;ignored####invalidkeys,invalidkeys,invalidkeys
      end


      def create_new_trace_state(parent_span_context, decision, xtraceoptions)
        decision = sw_from_span_and_decision(parent_span_context, decision)
        trace_state = ::OpenTelemetry::Trace::Tracestate.from_hash({SolarWindsOTelAPM::Constants::INTL_SWO_TRACESTATE_KEY => decision}) # e.g. sw=3e222c863a04123a-01
        SolarWindsOTelAPM.logger.debug "Created new trace_state: #{trace_state.inspect}"
        return trace_state
      end


      # 
      # calculate_trace_state
      # This function merely just add sw=value and xtrace_options_response=value into the old/new tracestate 
      # The return value tracestate will be used in propagating to next services
      # 
      def calculate_trace_state(decision, parent_span_context, xtraceoptions)
        SolarWindsOTelAPM.logger.debug "calculate_trace_state parent_span_context: #{parent_span_context.inspect}"
        if !parent_span_context.valid?
          
          trace_state = create_new_trace_state(parent_span_context, decision, xtraceoptions)
        else

          parent_trace_state = parent_span_context.tracestate
          if parent_trace_state.nil?
            trace_state = create_new_trace_state(parent_span_context, decision, xtraceoptions)
          else
            trace_state = parent_trace_state.set_value(SolarWindsOTelAPM::Constants::INTL_SWO_TRACESTATE_KEY, sw_from_span_and_decision(parent_span_context, decision))
            SolarWindsOTelAPM.logger.debug "Updated trace_state with span_id and sw trace_flags: #{trace_state.inspect}"
          end
        end

        # for setting up the xtrace_options_response
        if xtraceoptions && xtraceoptions.options
          trace_state = trace_state.set_value(
            "#{XTraceOptions.get_sw_xtraceoptions_response_key}",
            create_xtraceoptions_response_value(decision,parent_span_context,xtraceoptions)
          )
        end

        trace_state
      end

      #
      # SW_TRACESTATE_CAPTURE_KEY = "sw.w3c.tracestate"
      # get_sw_xtraceoptions_response_key = "xtrace_options_response"
      # trace_state is the new trace_state from existing span information
      # parent_span_context.trace_state is from its parent 
      #
      def add_tracestate_capture_to_attributes_dict(attributes_dict, decision, trace_state, parent_span_context)
        
        tracestate_capture = attributes_dict[SW_TRACESTATE_CAPTURE_KEY]
        SolarWindsOTelAPM.logger.debug "####### tracestate_capture #{tracestate_capture.inspect}; attributes_dict #{attributes_dict.inspect}; trace_state #{trace_state.inspect}; parent_span_context: #{parent_span_context.inspect}"        

        # tracestate_capture seems always nil because attributes_dict never have the SW_TRACESTATE_CAPTURE_KEY (sw.w3c.tracestate)
        # since tracestate_capture is always nil, so the sw always have new value for sw=key
        if tracestate_capture.nil?
        
          trace_state_no_response = trace_state.delete(XTraceOptions.get_sw_xtraceoptions_response_key)
        
        else
          # Must retain all potential tracestate pairs for attributes
          attr_trace_state = ::OpenTelemetry::Trace::Tracestate.from_string(tracestate_capture)

          # This step generated the new sw=key for tracestate based on root parent_span_id
          new_attr_trace_state = attr_trace_state.set_value(SolarWindsOTelAPM::Constants::INTL_SWO_TRACESTATE_KEY, sw_from_span_and_decision(parent_span_context,decision))
          
          trace_state_no_response = new_attr_trace_state.delete(XTraceOptions.get_sw_xtraceoptions_response_key)
        end

        SolarWindsOTelAPM.logger.debug "####### trace_state_no_response #{trace_state_no_response.inspect}"

        # other approach
        trace_state_no_response = parent_span_context.tracestate.delete(XTraceOptions.get_sw_xtraceoptions_response_key)
        no_sw_count = trace_state_no_response.to_h.select { |k,v| k != "sw" }.count
        attributes_dict[SW_TRACESTATE_CAPTURE_KEY] = Transformer.trace_state_header(trace_state_no_response) if no_sw_count > 0 

        SolarWindsOTelAPM.logger.debug "####### attributes_dict #{attributes_dict.inspect}"
        return attributes_dict
      end

      ##
      # calculate_attributes is used for getting the otel Result class in last step of sampler should_sample? e.g. result = Result.new(decision: otel_decision, attributes: new_attributes, tracestate: new_trace_state)
      # calculate_attributes use new_trace_state that is derived from current span information and old tracestate from parent_span_context.tracestate
      # the sw.w3c.tracestate should perserve the old tracestate value for debugging purpose
      ##
      def calculate_attributes(span_name, attributes, decision, trace_state, parent_span_context, xtraceoptions)
        SolarWindsOTelAPM.logger.debug "Received attributes: #{attributes.inspect}; decision:#{decision.inspect}; trace_state:#{trace_state.inspect}; parent_span_context:#{parent_span_context.inspect}; xtraceoptions:#{xtraceoptions.inspect}"

        otel_decision = otel_decision_from_liboboe(decision)
        return nil if Transformer.is_sampled?(otel_decision) == false
        
        SolarWindsOTelAPM.logger.debug("Trace decision is_sampled - setting attributes #{otel_decision.inspect}")

        new_attributes = {}
        # Copy existing MappingProxyType KV into new_attributes for modification.
        attributes.each {|k,v| new_attributes[k] = v } if attributes

        # Always (root or is_remote) set _INTERNAL_SW_KEYS if injected
        new_attributes[INTERNAL_SW_KEYS] = xtraceoptions.sw_keys if xtraceoptions.sw_keys

        # Always (root or is_remote) set custom KVs if extracted from x-trace-options
        xtraceoptions.custom_kvs.each { |k,v| new_attributes[k] = v } if xtraceoptions.custom_kvs

        # Always (root or is_remote) set service entry internal KVs       
        new_attributes[INTERNAL_BUCKET_CAPACITY] = decision["bucket_cap"].to_s
        new_attributes[INTERNAL_BUCKET_RATE]     = decision["bucket_rate"].to_s
        new_attributes[INTERNAL_SAMPLE_RATE]     = decision["rate"]
        new_attributes[INTERNAL_SAMPLE_SOURCE]   = decision["source"]
        SolarWindsOTelAPM.logger.debug "Set attributes with service entry internal KVs: #{new_attributes}"

        # set sw.tracestate_parent_id if its tracestate contains "sw"
        sw_value = parent_span_context.tracestate.value(SolarWindsOTelAPM::Constants::INTL_SWO_TRACESTATE_KEY)
        SolarWindsOTelAPM.logger.debug "####### calculate_attributes sw_value: #{sw_value.inspect} parent_span_context.tracestate #{parent_span_context.tracestate.inspect}"
        new_attributes[SW_TRACESTATE_ROOT_KEY]= Transformer.span_id_from_sw(sw_value) if sw_value && parent_span_context.remote?

        # If unsigned or signed TT (root or is_remote), set TriggeredTrace
        new_attributes[SolarWindsOTelAPM::Constants::INTERNAL_TRIGGERED_TRACE] = true if xtraceoptions.trigger_trace

        # Trace's root span has no valid traceparent nor tracestate so we can't calculate remaining attributes
        if !parent_span_context.valid? || trace_state.nil?
          SolarWindsOTelAPM.logger.debug "No valid traceparent or no tracestate - returning attributes: #{new_attributes}"
          return new_attributes.freeze if new_attributes
          return nil
        end

        new_attributes = add_tracestate_capture_to_attributes_dict(new_attributes,decision,trace_state,parent_span_context)
        # e.g. {"SWKeys"=>"check-id:check-1013,website-id:booking-demo", "BucketCapacity"=>"6.0", "BucketRate"=>"0.1", "SampleRate"=>-1, "SampleSource"=>-1, "http.method"=>"GET", "http.host"=>"0.0.0.0:8002", "http.scheme"=>"http", "http.target"=>"/call_second_rails/", "http.user_agent"=>"curl/7.81.0", "sw.w3c.tracestate"=>"sw=aaaa1111bbbb2222-01"}
        return new_attributes.freeze
      end

      def sw_from_span_and_decision(parent_span_context, decision)
        trace_flag = Transformer.trace_flags_from_boolean(decision["do_sample"])
        return Transformer.sw_from_span_and_decision(parent_span_context.hex_span_id, trace_flag)
      end


    end
  end
end