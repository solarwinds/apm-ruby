#--
# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.
#++

# Make sure Set is loaded if possible.
begin
  require 'set'
rescue LoadError
  class Set; end # :nodoc:
end

module SolarWindsOTelAPM
  module API
    ##
    # This modules provides the X-Trace logging facilities.
    #
    # These are the lower level methods, please see SolarWindsOTelAPM::SDK
    # for the higher level methods
    #
    # If using these directly make sure to always match a start/end and entry/exit to
    # avoid broken traces.
    module Logging
      @@ints_or_nil = [Integer, Float, NilClass, String]

      ##
      # Public: Report an event in an active trace.
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +label+ - The label for the reported event. See SDK documentation for reserved labels and usage.
      # * +kvs+  - A hash containing key/value pairs that will be reported along with this event (optional).
      # * +event+ - An event to be used instead of generating a new one (see also start_trace_with_target)
      #
      # ==== Example
      #
      #   SolarWindsOTelAPM::API.log('logical_layer', 'entry')
      #   SolarWindsOTelAPM::API.log('logical_layer', 'info', { :list_length => 20 })
      #   SolarWindsOTelAPM::API.log('logical_layer', 'exit')
      #
      # Returns nothing.
      def log(layer, label, kvs = {}, event = nil)
        return SolarWindsOTelAPM::Context.toString unless SolarWindsOTelAPM.tracing?

        event ||= SolarWindsOTelAPM::Context.createEvent
        log_event(layer, label, event, kvs)
      end

      ##
      # Public: Report an exception.
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +exception+ - The exception to report, responds to :message and :backtrace(optional)
      # * +kvs+ - Custom params if you want to log extra information
      #
      # ==== Example
      #
      #   begin
      #     my_iffy_method
      #   rescue Exception => e
      #     SolarWindsOTelAPM::API.log_exception('rails', e, { user: user_id })
      #     raise
      #   end
      #
      # Returns nothing.
      def log_exception(layer, exception, kvs = {})
        return SolarWindsOTelAPM::Context.toString if !SolarWindsOTelAPM.tracing? || exception.instance_variable_get(:@exn_logged)

        unless exception
          SolarWindsOTelAPM.logger.debug '[solarwinds_apm/debug] log_exception called with nil exception'
          return SolarWindsOTelAPM::Context.toString
        end

        exception.message << exception.class.name if exception.message.length < 4
        kvs.merge!(:Spec => 'error',
                   :ErrorClass => exception.class.name,
                   :ErrorMsg => exception.message)

        if exception.respond_to?(:backtrace) && exception.backtrace
          kvs.merge!(:Backtrace => exception.backtrace.join("\r\n"))
        end

        exception.instance_variable_set(:@exn_logged, true)
        log(layer, :error, kvs)
      end

      ##
      # Public: Start a trace depending on TransactionSettings
      # or decide whether or not to start a trace, and report an entry event
      # appropriately.
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +kvs+ - A hash containing key/value pairs that will be reported along with this event (optional).
      # * +headers+ - the request headers, they may contain w3c trace_context data
      # * +settings+ - An instance of TransactionSettings
      # * +url+ - String of the current url, it may be configured to be excluded from tracing
      #
      # ==== Example
      #
      #   SolarWindsOTelAPM::API.log_start(:layer_name, { :id => @user.id })
      #
      # Returns a metadata string if we are tracing
      #
      def log_start(layer, kvs = {}, headers = {}, settings = nil, url = nil)
        return unless SolarWindsOTelAPM.loaded

        # This is a bit ugly, but here is the best place to reset the layer_op thread local var.
        SolarWindsOTelAPM.layer_op = nil

        settings ||= SolarWindsOTelAPM::TransactionSettings.new(url, headers)
        SolarWindsOTelAPM.trace_context.add_traceinfo(kvs)
        tracestring = SolarWindsOTelAPM.trace_context.tracestring

        if settings.do_sample
          kvs[:SampleRate]        = settings.rate
          kvs[:SampleSource]      = settings.source

          SolarWindsOTelAPM::TraceString.set_sampled(tracestring) if tracestring
          event = create_start_event(tracestring)
          log_event(layer, :entry, event, kvs)
        else
          create_nontracing_context(tracestring)
          SolarWindsOTelAPM::Context.toString
        end
      end

      ##
      # Public: Report an exit event and potentially clear the tracing context.
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +kvs+ - A hash containing key/value pairs that will be reported along with this event (optional).
      #
      # ==== Example
      #
      #   SolarWindsOTelAPM::API.log_end(:layer_name, { :id => @user.id })
      #
      # Returns a metadata string if we are tracing
      #
      def log_end(layer, kvs = {}, event = nil)
        return SolarWindsOTelAPM::Context.toString unless SolarWindsOTelAPM.tracing?

        event ||= SolarWindsOTelAPM::Context.createEvent
        log_event(layer, :exit, event, kvs)
      ensure
        SolarWindsOTelAPM::Context.clear
        SolarWindsOTelAPM.trace_context = nil
        SolarWindsOTelAPM.transaction_name = nil
      end

      ##
      # Public: Log an entry event
      #
      # A helper method to create and log an entry event
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +kvs+ - A hash containing key/value pairs that will be reported along with this event (optional).
      # * +op+ - To identify the current operation being traced.  Used to avoid double tracing recursive calls.
      #
      # ==== Example
      #
      #   SolarWindsOTelAPM::API.log_entry(:layer_name, { :id => @user.id })
      #
      # Returns a metadata string
      #
      def log_entry(layer, kvs = {}, op = nil)
        return SolarWindsOTelAPM::Context.toString unless SolarWindsOTelAPM.tracing?

        if op
          # check if re-entry but also add op to list for log_exit
          re_entry = SolarWindsOTelAPM.layer_op&.last == op.to_sym
          SolarWindsOTelAPM.layer_op = (SolarWindsOTelAPM.layer_op || []) << op.to_sym
          return SolarWindsOTelAPM::Context.toString if re_entry
        end

        event ||= SolarWindsOTelAPM::Context.createEvent
        log_event(layer, :entry, event, kvs)
      end

      ##
      # Public: Log an info event
      #
      # A helper method to create and log an info event
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +kvs+ - A hash containing key/value pairs that will be reported along with this event (optional).
      #
      # ==== Example
      #
      #   SolarWindsOTelAPM::API.log_info(:layer_name, { :id => @user.id })
      #
      # Returns a metadata string if we are tracing
      #
      def log_info(layer, kvs = {})
        return SolarWindsOTelAPM::Context.toString unless SolarWindsOTelAPM.tracing?

        kvs[:Spec] = 'info'
        log_event(layer, :info, SolarWindsOTelAPM::Context.createEvent, kvs)
      end

      ##
      # Public: Log an exit event
      #
      # A helper method to create and log an exit event
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +kvs+  - A hash containing key/value pairs that will be reported along with this event (optional).
      # * +op+    - Used to avoid double tracing recursive calls, needs to be the same in +log_exit+ that corresponds to a
      #   +log_entry+
      #
      # ==== Example
      #
      #   SolarWindsOTelAPM::API.log_exit(:layer_name, { :id => @user.id })
      #
      # Returns a metadata string  if we are tracing
      def log_exit(layer, kvs = {}, op = nil)
        return SolarWindsOTelAPM::Context.toString unless SolarWindsOTelAPM.tracing?

        if op
          if SolarWindsOTelAPM.layer_op&.last == op.to_sym
            SolarWindsOTelAPM.layer_op.pop
          else
            SolarWindsOTelAPM.logger.warn "[ruby/logging] op parameter of exit event doesn't correspond to an entry event op"
          end
          # check if the next op is the same, don't log event if so
          return SolarWindsOTelAPM::Context.toString if SolarWindsOTelAPM.layer_op&.last == op.to_sym
        end

        log_event(layer, :exit, SolarWindsOTelAPM::Context.createEvent, kvs)
      end

      ##
      #:nodoc:
      # Internal: Reports agent init to the collector
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +kvs+ - A hash containing key/value pairs that will be reported along with this event
      def log_init(layer = :rack, kvs = {})
        context = SolarWindsOTelAPM::Metadata.makeRandom
        return SolarWindsOTelAPM::Context.toString unless context.isValid

        event = context.createEvent
        event.addInfo(SW_APM_STR_LAYER, layer.to_s)
        event.addInfo(SW_APM_STR_LABEL, 'single')
        kvs.each do |k, v|
          event.addInfo(k, v.to_s)
        end

        SolarWindsOTelAPM::Reporter.sendStatus(event, context)
        SolarWindsOTelAPM::Context.toString
      end

      private

      ##
      #:nodoc:
      # @private
      # Internal: Report an event.
      #
      # ==== Arguments
      #
      # * +layer+ - The layer the reported event belongs to
      # * +label+ - The label for the reported event.  See API documentation for reserved labels and usage.
      # * +event+ - The pre-existing SolarWindsOTelAPM context event.  See SolarWindsOTelAPM::Context.createEvent
      # * +kvs+ - A hash containing key/value pairs that will be reported along with this event (optional).
      #
      # ==== Example
      #
      #   entry = SolarWindsOTelAPM::Context.createEvent
      #   SolarWindsOTelAPM::API.log_event(:layer_name, 'entry',  entry_event, { :id => @user.id })
      #
      #   exit_event = SolarWindsOTelAPM::Context.createEvent
      #   exit_event.addEdge(entry.getMetadata)
      #   SolarWindsOTelAPM::API.log_event(:layer_name, 'exit',  exit_event, { :id => @user.id })
      #
      def log_event(layer, label, event, kvs = {})
        event.addInfo(SW_APM_STR_LAYER, layer.to_s.freeze) if layer
        event.addInfo(SW_APM_STR_LABEL, label.to_s.freeze)

        SolarWindsOTelAPM.layer = layer.to_sym if label == :entry
        SolarWindsOTelAPM.layer = nil          if label == :exit

        kvs.each do |k, v|
          value = nil

          next unless valid_key? k

          if @@ints_or_nil.include?(v.class)
            value = v
          elsif v.class == Set
            value = v.to_a.to_s
          else
            value = v.to_s if v.respond_to?(:to_s)
          end

          begin
            event.addInfo(k.to_s, value)
          rescue ArgumentError => e
            SolarWindsOTelAPM.logger.debug "[solarwinds_apm/debug] Couldn't add event KV: #{k} => #{v.class}"
            SolarWindsOTelAPM.logger.debug "[solarwinds_apm/debug] #{e.message}"
          end
        end if !kvs.nil? && kvs.any?

        SolarWindsOTelAPM::Reporter.sendReport(event)
        SolarWindsOTelAPM::Context.toString
      end

      def create_start_event(tracestring = nil)
        if SolarWindsOTelAPM::TraceString.sampled?(tracestring)
          md = SolarWindsOTelAPM::Metadata.fromString(tracestring)
          SolarWindsOTelAPM::Context.fromString(tracestring)
          md.createEvent
        else
          md = SolarWindsOTelAPM::Metadata.makeRandom(true)
          SolarWindsOTelAPM::Context.set(md)
          SolarWindsOTelAPM::Event.startTrace(md)
        end
      end

      public

      def create_nontracing_context(tracestring)
        if SolarWindsOTelAPM::TraceString.valid?(tracestring)
          # continue valid incoming tracestring
          # use it for current context, ensuring sample bit is not set
          SolarWindsOTelAPM::TraceString.unset_sampled(tracestring)
          SolarWindsOTelAPM::Context.fromString(tracestring)
        else
          # discard invalid incoming tracestring
          # create a new context, ensuring sample bit not set
          md = SolarWindsOTelAPM::Metadata.makeRandom(false)
          SolarWindsOTelAPM::Context.fromString(md.toString)
        end
      end

      # need to set the module context to public, otherwise the following `extends` will be private in api.rb

      public

    end
  end
end
