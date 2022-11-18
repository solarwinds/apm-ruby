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

        SolarWindsOTelAPM.logger.debug "#{trace_id.unpack1("H*")}\n#{parent_context}\n#{links}\n#{name}\n#{kind}\n#{attributes}"
        parent_span_context = Transformer.get_current_span(parent_context).context

        xtraceoptions       = SolarWindsOTelAPM::XTraceOptions.new(parent_context)
        liboboe_decision    = calculate_liboboe_decision(parent_span_context,xtraceoptions)

        # Always calculate trace_state for propagation
        new_trace_state = calculate_trace_state(liboboe_decision,parent_span_context,xtraceoptions)
        new_attributes  = calculate_attributes(name,attributes,liboboe_decision,new_trace_state,parent_span_context,xtraceoptions)
        otel_decision   = otel_decision_from_liboboe(liboboe_decision)

        sampling_result = nil
        if Transformer.is_sampled?(otel_decision)
          sampling_result = ::OpenTelemetry::SDK::Trace::Samplers::Result.new(decision: otel_decision, attributes: new_attributes, tracestate: new_trace_state)
        else
          sampling_result = ::OpenTelemetry::SDK::Trace::Samplers::Result.new(decision: otel_decision, attributes: nil, tracestate: new_trace_state)
        end

        return sampling_result

      end

      protected

      attr_reader :decision

      private

      def init_context
        context = (SolarWindsOTelAPM.loaded == true)? SolarWindsOTelAPM::Context : nil
      end

      # return Hash
      def calculate_liboboe_decision parent_span_context, xtraceoptions

        tracestring = nil
        if parent_span_context.valid? && parent_span_context.remote?
          tracestring = Transformer.traceparent_from_context(parent_span_context)
        end

        sw_member_value = parent_span_context.tracestate[SolarWindsOTelAPM::Constants::INTL_SWO_TRACESTATE_KEY]
        tracing_mode = UNSET # 'tracing_mode' is not supported in NH Python, so give as unset

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

        SolarWindsOTelAPM.logger.debug "decision parameters \n 
                                         tracestring     #{tracestring}\n
                                         sw_member_value #{sw_member_value}\n
                                         tracing_mode    #{tracing_mode}\n
                                         sample_rate     #{sample_rate}\n
                                         trigger_trace   #{trigger_trace}\n
                                         trigger_trace_mode    #{trigger_trace_mode}\n
                                         options      #{options}\n
                                         signature    #{signature}\n
                                         timestamp    #{timestamp}\n"

        args = [tracestring,sw_member_value,tracing_mode,sample_rate,trigger_trace,trigger_trace_mode,options,signature,timestamp] 
        do_metrics, do_sample, rate, source, bucket_rate, \
            bucket_cap, decision_type, auth, status_msg, auth_msg, status = SolarWindsOTelAPM::Context.getDecisions(*args)

        decision = Hash.new
        decision["do_metrics"]    = do_metrics
        decision["do_sample"]     = do_sample
        decision["rate"]          = rate
        decision["source"]        = source
        decision["bucket_rate"]   = bucket_rate
        decision["bucket_cap"]    = bucket_cap
        decision["decision_type"] = decision_type
        decision["auth"]          = auth
        decision["status_msg"]    = status_msg
        decision["auth_msg"]      = auth_msg
        decision["status"]        = status

        SolarWindsOTelAPM.logger.debug "Got liboboe decision outputs: #{decision.inspect}"
        return decision

      end


      def otel_decision_from_liboboe liboboe_decision

        decision = ::OpenTelemetry::SDK::Trace::Samplers::Decision::DROP
        if liboboe_decision["do_sample"]
          decision = ::OpenTelemetry::SDK::Trace::Samplers::Decision::RECORD_AND_SAMPLE  # even if not do_metrics
        elsif liboboe_decision["do_metrics"]
          decision = ::OpenTelemetry::SDK::Trace::Samplers::Decision::RECORD_ONLY
        end
        SolarWindsOTelAPM.logger.debug "OTel decision created: #{decision}"
        return decision

      end

      def create_xtraceoptions_response_value decision, parent_span_context, xtraceoptions

        response = Array.new

        if xtraceoptions.signature && decision["auth_msg"]
          response << [XTRACEOPTIONS_RESP_AUTH,decision["auth_msg"]].join(SolarWindsOTelAPM::Constants::INTL_SWO_EQUALS_W3C_SANITIZED)
        end

        if !decision["auth"] || decision["auth"] < 1
          trigger_msg = ""
          if xtraceoptions.trigger_trace
            # If a traceparent header was provided then oboe does not generate the message
            tracestring = nil
            if parent_span_context.valid? && parent_span_context.remote?
              tracestring = Transformer.traceparent_from_context(parent_span_context)
            end
            if tracestring && decision["decision_type"] == 0
              trigger_msg = XTRACEOPTIONS_RESP_TRIGGER_IGNORED
            else
              trigger_msg = decision["status_msg"]
            end
          else
            trigger_msg = XTRACEOPTIONS_RESP_TRIGGER_NOT_REQUESTED
          end

          response << [XTRACEOPTIONS_RESP_TRIGGER_TRACE, trigger_msg].join(SolarWindsOTelAPM::Constants::INTL_SWO_EQUALS_W3C_SANITIZED)
        end

        if xtraceoptions.ignored
          ignored_response = [XTRACEOPTIONS_RESP_IGNORED, xtraceoptions.ignored.join(SolarWindsOTelAPM::Constants::INTL_SWO_COMMA_W3C_SANITIZED)]
          response << ignored_response.join(SolarWindsOTelAPM::Constants::INTL_SWO_EQUALS_W3C_SANITIZED)
        end

        response.join(";")

      end


      def create_new_trace_state decision, parent_span_context, xtraceoptions

        decision = Transformer.sw_from_span_and_decision(parent_span_context.hex_span_id, Transformer.trace_flags_from_int(decision["do_sample"]))
        trace_state_hash = Hash.new
        trace_state_hash[SolarWindsOTelAPM::Constants::INTL_SWO_TRACESTATE_KEY] = decision
        trace_state = ::OpenTelemetry::Trace::Tracestate.from_hash(trace_state_hash)

        if xtraceoptions && xtraceoptions.trigger_trace
          trace_state = trace_state.set_value(
            "#{XTraceOptions.get_sw_xtraceoptions_response_key}",
            create_xtraceoptions_response_value(decision,parent_span_context,xtraceoptions)
          )
        end

        SolarWindsOTelAPM.logger.debug "Created new trace_state: #{trace_state}"
        return trace_state
      end


      def calculate_trace_state decision, parent_span_context, xtraceoptions

        if !parent_span_context.valid?
          trace_state = create_new_trace_state(decision,parent_span_context,xtraceoptions)
        else
          trace_state = parent_span_context.tracestate
          if trace_state.nil?
            # tracestate nonexistent/non-parsable
            trace_state = create_new_trace_state(decision,parent_span_context,xtraceoptions)
          else
            # Update trace_state with span_id and sw trace_flags
            trace_state = trace_state.set_value(
              "#{SolarWindsOTelAPM::Constants::INTL_SWO_TRACESTATE_KEY}",
              Transformer.sw_from_span_and_decision(parent_span_context.hex_span_id, Transformer.trace_flags_from_int(decision["do_sample"]))
            )
            # Update trace_state with x-trace-options-response
            # Not a propagated header, so always an add
            if xtraceoptions && xtraceoptions.trigger_trace
                trace_state = trace_state.set_value(
                  "#{XTraceOptions.get_sw_xtraceoptions_response_key}",
                  create_xtraceoptions_response_value(decision,parent_span_context,xtraceoptions)
                )
            end
            SolarWindsOTelAPM.logger.debug "Updated trace_state: #{trace_state}"
          end
        end
        return trace_state


      end

      def remove_response_from_sw trace_state
        return trace_state.delete(XTraceOptions.get_sw_xtraceoptions_response_key)
      end

      def add_tracestate_capture_to_attributes_dict attributes_dict, decision, trace_state, parent_span_context

        tracestate_capture = attributes_dict[SW_TRACESTATE_CAPTURE_KEY]
        if tracestate_capture
          trace_state_no_response = remove_response_from_sw(trace_state)
        else
          # Must retain all potential tracestate pairs for attributes
          attr_trace_state = ::OpenTelemetry::Trace::Tracestate.from_hash(tracestate_capture)

          new_attr_trace_state = attr_trace_state.set_value(
              "#{INTL_SWO_TRACESTATE_KEY}",
              Transformer.sw_from_span_and_decision(parent_span_context.hex_span_id,Transformer.trace_flags_from_int(decision["do_sample"]))
          )
          trace_state_no_response = remove_response_from_sw(new_attr_trace_state)
        end

        attributes_dict["#{SW_TRACESTATE_CAPTURE_KEY}"] = Transformer.trace_state_header(trace_state_no_response)
        return attributes_dict


      end

      def calculate_attributes span_name, attributes, decision, trace_state, parent_span_context, xtraceoptions
        SolarWindsOTelAPM.logger.debug "Received attributes: #{attributes}"
        # Don't set attributes if not tracing
        otel_decision = otel_decision_from_liboboe(decision)
        if Transformer.is_sampled?(otel_decision)
          SolarWindsOTelAPM.logger.debug("Trace decision not is_sampled - not setting attributes")
          return nil
        end
        
        new_attributes = {}

        # Always (root or is_remote) set _INTERNAL_SW_KEYS if injected
        new_attributes[INTERNAL_SW_KEYS] = xtraceoptions.sw_keys if xtraceoptions.sw_keys

        # Always (root or is_remote) set service entry internal KVs       
        new_attributes[INTERNAL_BUCKET_CAPACITY] = "#{decision["bucket_cap"]}"
        new_attributes[INTERNAL_BUCKET_RATE]     = "#{decision["bucket_rate"]}"
        new_attributes[INTERNAL_SAMPLE_RATE]     = decision["rate"]
        new_attributes[INTERNAL_SAMPLE_SOURCE]   = decision["source"]
        SolarWindsOTelAPM.logger.debug "Set attributes with service entry internal KVs: #{new_attributes}"

        # Trace's root span has no valid traceparent nor tracestate
        # so we can't calculate remaining attributes
        if !parent_span_context.valid? or trace_state.nil?
          SolarWindsOTelAPM.logger.debug "No valid traceparent or no tracestate - returning attributes: #{new_attributes}"
          if new_attributes
            # attributes must be immutable for SamplingResult
            # MappingProxyType is a readonly key value object data structure
            # need to create one in ruby
            return new_attributes.freeze
          else
            return nil
          end
        end

        if attributes.nil?
          # _SW_TRACESTATE_ROOT_KEY is set once per trace, if possible
          sw_value = parent_span_context.tracestate.value("#{SolarWindsOTelAPM::Constants::INTL_SWO_TRACESTATE_KEY}")
          if sw_value
            new_attributes[SW_TRACESTATE_ROOT_KEY]= Transformer.span_id_from_sw(sw_value)
          end
        else
          # Copy existing MappingProxyType KV into new_attributes for modification.
          # attributes may have other vendor info etc
          attributes.each do |k,v|
            new_attributes[k] = v
          end
        end

        new_attributes = add_tracestate_capture_to_attributes_dict(new_attributes,decision,trace_state,parent_span_context)

        SolarWindsOTelAPM.logger.debug "Setting attributes: #{new_attributes}"

        # attributes must be immutable for SamplingResult
        return new_attributes.freeze
      end



    end
  end
end