#--
# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.
#++

module SolarWindsAPM
  module SDK
    ##
    # Traces are best created with an <tt>SolarWindsAPM::SDK.start_trace</tt> block and
    # <tt>SolarWindsAPM::SDK.trace</tt> blocks around calls to be traced.
    # These two methods guarantee proper nesting of traces, handling of the tracing context, as well as avoiding
    # broken traces in case of exceptions.
    #
    # Some optional keys that can be used in the +kvs+ hash:
    # * +:Controller+
    # * +:Action+
    # * +:HTTP-Host+
    # * +:URL+
    # * +:Method+
    #
    # as well as custom keys. The information will show up in the raw data view of a span.
    #
    # Invalid keys: +:Label+, +:Layer+, +:Edge+, +:Timestamp+, +:Timestamp_u+, +:TransactionName+ (allowed in start_trace)
    #
    # The methods are exposed as singleton methods for SolarWindsAPM::SDK.
    #
    # === Usage:
    # * +SolarWindsAPM::SDK.solarwinds_ready?+
    # * +SolarWindsAPM::SDK.get_transaction_name+
    # * +SolarWindsAPM::SDK.set_transaction_name+
    # * +SolarWindsAPM::SDK.start_trace+
    # * +SolarWindsAPM::SDK.start_trace_with_target+
    # * +SolarWindsAPM::SDK.trace+
    # * +SolarWindsAPM::SDK.trace_method+
    # * +SolarWindsAPM::SDK.tracing?+
    #
    # === Example:
    #   class MonthlyCouponEmailJob
    #     def perform(*args)
    #
    #       # KVs to report to the dashboard
    #       report_kvs = {}
    #       report_kvs[:Spec] = :job
    #       report_kvs[:Controller] = :MonthlyEmailJob
    #       report_kvs[:Action] = :CouponEmailer
    #
    #       # Start tracing this job with start_trace
    #       SolarWindsAPM::SDK.start_trace('monthly_coupons', kvs: report_kvs) do
    #         monthly = MonthlyEmail.new(:CouponEmailer)
    #
    #         # Trace a sub-component of this trace
    #         SolarWindsAPM::SDK.trace(self.class.name) do
    #
    #           # The work to be done
    #           users = User.all
    #           users.each do |u|
    #             monthly.send(u.email)
    #           end
    #
    #         end
    #       end
    #     end
    #   end
    #
    module Tracing
      # Trace a given block of code.
      #
      # Also detects any exceptions thrown by the block and report errors.
      # The exporter will handle the context.createEntry and context.createExit method
      #
      # === Arguments:
      # * +name+        - Name for the span to be used as label in the trace view.
      # * +kvs:+        - (optional) A hash containing key/value pairs that will be reported along with the first event of this span.
      # * +protect_op:+ - (optional) The operation being traced.  Used to avoid double tracing operations that call each other.
      #
      # === Example:
      #
      #   def computation_with_sw_apm(n)
      #     SolarWindsAPM::SDK.trace('computation', kvs: { :number => n }, protect_op: :computation) do
      #       return n if n == 0
      #       n + computation_with_sw_apm(n-1)
      #     end
      #   end
      #
      #   result = computation_with_sw_apm(100)
      #
      # === Returns:
      # * The result of the block.
      #
      def trace(name, kvs: {}, protect_op: nil, &block) # rubocop:disable Lint/UnusedMethodArgument

        SolarWindsAPM.logger.warn {"SolarWindsAPM::SDK.trace will be depreciated soon. Please either use otel ruby in_span or SolarWindsAPM::API.in_span"}

        return yield unless SolarWindsAPM.loaded
        
        kvs.delete(:TransactionName) && kvs.delete('TransactionName')
        links  = kvs.delete(:links) && kvs.delete('links')
        kind   = kvs.delete(:kinds) && kvs.delete('kinds')
        SolarWindsAPM::API.in_span(name, attributes: kvs, links: links, start_timestamp: nil, kind: kind, &block)
      end

      # Collect metrics and start tracing a given block of code.
      #
      # This will start a trace depending on configuration and probability, detect any exceptions
      # thrown by the block, and report errors.
      #
      # This method is for request entry points where no trace has been started yet
      # Nested calls to start_trace() will have the inner call override the outer call
      # The behavior may be unexpected. After a trace is started with start_trace()
      # trace() should be used to create spans within the started trace
      #
      # When start_trace returns control to the calling context, the trace will be
      # completed and the tracing context will be cleared.
      #
      # === Arguments:
      #
      # * +name+   - Name for the span to be used as label in the trace view.
      # * +kvs:+    - (optional) hash containing key/value pairs that will be reported with this span.
      #              The value of :TransactionName entry will set the transaction_name.
      # * +headers:+ - hash containing incoming headers to extract w3c trace context
      #
      # === Example:
      #
      #   def handle_request(request, response)
      #     # ... code that processes request and response ...
      #   end
      #
      #   def handle_request_with_sw_apm(request, response)
      #     SolarWindsAPM::SDK.start_trace('custom_trace', kvs: { :TransactionName => 'handle_request' }) do
      #       handle_request(request, response)
      #     end
      #   end
      #
      # === Returns:
      # * The result of the block.
      #
      def start_trace(name, kvs: {}, headers: {}, &block)
        SolarWindsAPM.logger.warn {"SolarWindsAPM::SDK.start_trace will be depreciated soon. Please either use otel ruby in_span or SolarWindsAPM::API.in_span"}
        start_trace_with_target(name, target: {}, kvs: kvs, headers: headers, &block)
      end

      # Collect metrics, trace a given block of code, and assign trace info to target.
      #
      # This will start a trace depending on configuration and probability, detect any exceptions
      # thrown by the block, report errors, and assign an X-Trace to the target.
      #
      # The motivating use case for this is HTTP streaming in rails3. We need
      # access to the exit event's trace id so we can set the header before any
      # work is done, and before any headers are sent back to the client.
      # 
      # start_trace_with_target as the function from start_trace, it should create root_span by default
      #
      # === Arguments:
      # * +name+   - Name for the span to be used as label in the trace view.
      # * +target:+ - (optional) has to respond to #[]=, The target object in which to place the trace information.
      # * +kvs:+    - (optional) Hash containing key/value pairs that will be reported with this span.
      # * +headers:+ - (optional) Hash containing incoming headers to extract w3c trace context
      #
      # === Example:
      #
      #   def handle_request(request, response)
      #     # ... code that processes request and response ...
      #   end
      #
      #   def handle_request_with_sw_apm(request, response)
      #     SolarWindsAPM::SDK.start_trace_with_target('rails', headers: request.headers, target: response) do
      #       handle_request(request, response)
      #     end
      #   end
      #
      # === Returns:
      # * The result of the block.
      #
      def start_trace_with_target(name, target: {}, kvs: {}, headers: {}, &block) # rubocop:disable Lint/UnusedMethodArgument
        return yield unless SolarWindsAPM.loaded

        kvs.delete(:TransactionName) && kvs.delete('TransactionName')
        links  = kvs.delete(:links) && kvs.delete('links')
        kind   = kvs.delete(:kinds) && kvs.delete('kinds')

        SolarWindsAPM::API.in_span(name, attributes: kvs, links: links, start_timestamp: nil, kind: kind, &block)
      end

      ##
      # Add tracing to a given method
      #
      # This instruments the given method so that every time it is called it
      # will create a span depending on the current context.
      #
      # The method can be of any (accessible) type (instance, singleton,
      # private, protected etc.).
      # 
      # This method turn a normal function into a function that can send trace
      #
      # The motivating use case for this is MetalController methods in Rails,
      # which can't be auto-instrumented.
      #
      # === Arguments:
      # * +klass+  - The module/class the method belongs to.
      # * +method+ - The method name as symbol
      # * +config:+   - (optional) possible keys are:
      #              :name the name of the span (default: the method name)
      #              :backtrace true/false (default: false) if true the backtrace will be added to the space
      # * +kvs:+     - (optional) hash containing key/value pairs that will be reported with this span.
      #
      # === Example:
      #
      #   module ExampleModule
      #     def do_sum(a, b)
      #       a + b
      #     end
      #   end
      #
      #  SolarWindsAPM::SDK.trace_method(ExampleModule,
      #                                 :do_sum,
      #                                 config: {name: 'computation', backtrace: true},
      #                                 kvs: { CustomKey: "some_info"})
      #
      def trace_method(klass, method, config: {}, kvs: {})

        SolarWindsAPM.logger.warn {"SolarWindsAPM::SDK.trace_method will be depreciated soon."}

        # If we're on an unsupported platform (ahem Mac), just act
        # like we did something to nicely play the no-op part.
        return true unless SolarWindsAPM.loaded

        unless klass.is_a?(Module)
          SolarWindsAPM.logger.warn "[solarwinds_apm/error] trace_method: Not sure what to do with #{klass}.  Send a class or module."
          return false
        end

        if method.is_a?(String)
          method = method.to_sym
        elsif !method.is_a?(Symbol)
          SolarWindsAPM.logger.warn "[solarwinds_apm/error] trace_method: Not sure what to do with #{method}.  Send a string or symbol for method."
          return false
        end

        instance_method = klass.instance_methods.include?(method) || klass.private_instance_methods.include?(method)
        class_method = klass.singleton_methods.include?(method)

        # Make sure the request klass::method exists
        if !instance_method && !class_method
          SolarWindsAPM.logger.warn "[solarwinds_apm/error] trace_method: Can't instrument #{klass}.#{method} as it doesn't seem to exist."
          SolarWindsAPM.logger.warn "[solarwinds_apm/error] #{__FILE__}:#{__LINE__}"
          return false
        end

        # Strip '!' or '?' from method if present
        safe_method_name = method.to_s.chop if method.to_s =~ /\?$|\!$/
        safe_method_name ||= method

        without_sw_apm = "#{safe_method_name}_without_sw_apm"
        with_sw_apm    = "#{safe_method_name}_with_sw_apm"

        # Check if already profiled
        if instance_method && klass.instance_methods.include?(with_sw_apm.to_sym) ||
           class_method && klass.singleton_methods.include?(with_sw_apm.to_sym)
          SolarWindsAPM.logger.warn "[solarwinds_apm/error] trace_method: #{klass}::#{method} already instrumented.\n#{__FILE__}:#{__LINE__}"
          return false
        end

        report_kvs = kvs.dup
        if defined?(::AbstractController::Base) && klass.ancestors.include?(::AbstractController::Base)
          report_kvs[:Controller] = klass.to_s
          report_kvs[:Action] = method.to_s
        else
          klass.is_a?(Class) ? report_kvs[:Class] = klass.to_s : report_kvs[:Module] = klass.to_s
          report_kvs[:MethodName] = safe_method_name
        end

        from = 0
        to   = -1
        name = config[:name] || method
        if instance_method
          klass.class_eval do
            define_method(with_sw_apm) do |*args, &block|
              # if this is a rails controller we want to set the transaction for the outbound metrics
              if report_kvs[:Controller] && defined?(request) && defined?(request.env)
                request.env['solarwinds_apm.controller'] = report_kvs[:Controller]
                request.env['solarwinds_apm.action'] = report_kvs[:Action]
              end

              SolarWindsAPM::SDK.trace(name, kvs: report_kvs) do
                if config[:backtrace]
                  bt = Kernel.caller
                  if bt.is_a?(Array) && bt.size > 200
                    trim_backtrace = bt[0, 180] + ['...[snip]...'] + bt[bt.size - 20, 20]
                  else
                    trim_backtrace = bt
                  end
                  report_kvs[:Backtrace] = trim_backtrace[from..to].join("\r\n")
                end
                send(without_sw_apm, *args, &block)
              end
            end

            alias_method without_sw_apm, method.to_s
            alias_method method.to_s, with_sw_apm
          end
        elsif class_method
          klass.define_singleton_method(with_sw_apm) do |*args, &block|
            SolarWindsAPM::SDK.trace(name, kvs: report_kvs) do
              if config[:backtrace]
                bt = Kernel.caller
                if bt.is_a?(Array) && bt.size > 200
                  trim_backtrace = bt[0, 180] + ['...[snip]...'] + bt[bt.size - 20, 20]
                else
                  trim_backtrace = bt
                end
                report_kvs[:Backtrace] = trim_backtrace[from..to].join("\r\n")
              end
              send(without_sw_apm, *args, &block)
            end
          end

          klass.singleton_class.class_eval do
            alias_method without_sw_apm, method.to_s
            alias_method method.to_s, with_sw_apm
          end
        end
        true
      end

      ##
      # Provide a custom transaction name
      #
      # The SolarWindsAPM gem tries to create meaningful transaction names from controller+action
      # or something similar depending on the framework used. However, you may want to override the
      # transaction name to better describe your instrumented operation.
      #
      # Take note that on the dashboard the transaction name is converted to lowercase, and might be
      # truncated with invalid characters replaced. Method calls with an empty string or a non-string
      # argument won't change the current transaction name.
      #
      # The configuration +SolarWindsAPM.Config+['transaction_name']+['prepend_domain']+ can be set to
      # true to have the domain name prepended to the transaction name when an event or a metric are
      # logged. This is a global setting.
      #
      # === Argument:
      #
      # * +name+ - A non-empty string with the custom transaction name
      #
      # === Example:
      #
      #   class DogfoodsController < ApplicationController
      #
      #     def create
      #       @dogfood = Dogfood.new(params.permit(:brand, :name))
      #       @dogfood.save
      #
      #       SolarWindsAPM::SDK.set_transaction_name("dogfoodscontroller.create_for_#{params[:brand]}")
      #
      #       redirect_to @dogfood
      #     end
      #
      #   end
      #
      # === Returns:
      # * (String or nil) the current transaction name
      #
      def set_transaction_name(name) # rubocop:disable Naming/AccessorMethodName
        SolarWindsAPM.logger.warn {"SolarWindsAPM::SDK.get_transaction_name will be depreciated soon. Please use SolarWindsAPM::API.set_transaction_name."}
        SolarWindsAPM::API.set_transaction_name(name)
      end

      # Get the currently set custom transaction name.
      #
      # This is provided for testing
      #
      # === Returns:
      # * (String or nil) the current transaction name (without domain prepended)
      #
      def get_transaction_name # rubocop:disable Naming/AccessorMethodName
        SolarWindsAPM.logger.warn {"SolarWindsAPM::SDK.get_transaction_name will be depreciated soon."}

        solarwinds_processor       = SolarWindsAPM::OTelConfig.class_variable_get(:@@config)[:span_processor]
        current_span               = ::OpenTelemetry::Trace.current_span
        entry_trace_id             = current_span.context.hex_trace_id
        entry_span_id, = solarwinds_processor.txn_manager.get_root_context_h(entry_trace_id)&.split('-')
        
        solarwinds_processor.txn_manager.get("#{entry_trace_id}-#{entry_span_id}")
      end

      # Determine if this transaction is being traced.
      #
      # Tracing puts some extra load on a system, therefore not all transaction are traced.
      # The +tracing?+ method helps to determine this so that extra work can be avoided when not tracing.
      #
      # === Example:
      #
      #   kvs = expensive_info_gathering_method if SolarWindsAPM::SDK.tracing?
      #   SolarWindsAPM::SDK.trace('some_span', kvs: kvs) do
      #     db_request
      #   end
      #
      def tracing?
        SolarWindsAPM.logger.warn {"SolarWindsAPM::SDK.tracing? will be depreciated soon."}
        return false unless SolarWindsAPM.loaded

        SolarWindsAPM::Context.isSampled
      end

      # Wait for SolarWinds to be ready to send traces.
      #
      # This may be useful in short lived background processes when it is important to capture
      # information during the whole time the process is running. Usually SolarWinds doesn't block an
      # application while it is starting up.
      #
      # === Argument:
      #
      # * +wait_milliseconds+ (int, default 3000) the maximum time to wait in milliseconds
      #
      # === Example:
      #
      #   unless SolarWindsAPM::SDK.solarwinds_ready?(10_000)
      #     Logger.info "SolarWindsAPM not ready after 10 seconds, no metrics will be sent"
      #   end
      #
      def solarwinds_ready?(_wait_milliseconds=3000)
        SolarWindsAPM.logger.warn {"SolarWindsAPM::SDK.solarwinds_ready? will be depreciated soon. Please use SolarWindsAPM::API.solarwinds_ready?"}
        SolarWindsAPM::API.solarwinds_ready?
      end
    end
  end
end
