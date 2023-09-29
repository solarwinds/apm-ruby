# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'socket'
require 'opentelemetry-api'

module SolarWindsAPM
  module SWOMarginalia
    module Comment
      mattr_accessor :components, :lines_to_ignore, :prepend_comment
      SWOMarginalia::Comment.components ||= [:traceparent]
      # To add new components: 
      # Create file and load after swotel-ruby, and add following:
      # SolarWindsAPM::SWOMarginalia::Comment.component = [:user_defined]

      def self.update!(controller=nil)
        self.marginalia_controller = controller
      end

      def self.update_job!(job)
        self.marginalia_job = job
      end

      def self.update_adapter!(adapter)
        self.marginalia_adapter = adapter
      end

      def self.construct_comment
        ret = String.new
        components.each do |c|
          component_value = send(c)
          ret << "#{c}='#{component_value}'," if component_value.present?
        end
        ret.chop!
        escape_sql_comment(ret)
      end

      def self.construct_inline_comment
        return nil if inline_annotations.none?

        escape_sql_comment(inline_annotations.join)
      end

      def self.escape_sql_comment(str)
        str = str.gsub('/*', '').gsub('*/', '') while str.include?('/*') || str.include?('*/')
        str
      end

      def self.clear!
        self.marginalia_controller = nil
      end

      def self.clear_job!
        self.marginalia_job = nil
      end

      def self.marginalia_controller=(controller)
        Thread.current[:marginalia_controller] = controller
      end

      def self.marginalia_controller
        Thread.current[:marginalia_controller]
      end

      def self.marginalia_job=(job)
        Thread.current[:marginalia_job] = job
      end

      def self.marginalia_job
        Thread.current[:marginalia_job]
      end

      def self.marginalia_adapter=(adapter)
        Thread.current[:marginalia_adapter] = adapter
      end

      def self.marginalia_adapter
        Thread.current[:marginalia_adapter]
      end

      def self.application
        if defined?(::Rails.application)
          SWOMarginalia.application_name ||= ::Rails.application.class.name.split("::").first
        else
          SWOMarginalia.application_name ||= "rails"
        end

        SWOMarginalia.application_name
      end

      def self.job
        marginalia_job&.class&.name
      end

      def self.controller
        marginalia_controller.controller_name if marginalia_controller.respond_to? :controller_name
      end

      def self.controller_with_namespace
        marginalia_controller&.class&.name
      end

      def self.action
        marginalia_controller.action_name if marginalia_controller.respond_to? :action_name
      end

      def self.sidekiq_job
        marginalia_job["class"] if marginalia_job.respond_to?(:[])
      end

      DEFAULT_LINES_TO_IGNORE_REGEX = %r{\.rvm|/ruby/gems/|vendor/|marginalia|rbenv|monitor\.rb.*mon_synchronize}

      def self.line
        SWOMarginalia::Comment.lines_to_ignore ||= DEFAULT_LINES_TO_IGNORE_REGEX

        last_line = caller.detect do |line|
          line !~ SWOMarginalia::Comment.lines_to_ignore
        end
        return unless last_line
        
        root = if defined?(Rails) && Rails.respond_to?(:root)
                 Rails.root.to_s
               elsif defined?(RAILS_ROOT)
                 RAILS_ROOT
               else
                 ""
               end
        last_line = last_line[root.length..] if last_line.start_with? root
        last_line
      end

      def self.hostname
        @hostname ||= Socket.gethostname
      end

      def self.pid
        Process.pid
      end

      def self.request_id
        return unless marginalia_controller.respond_to?(:request) && marginalia_controller.request.respond_to?(:uuid)

        marginalia_controller.request.uuid  
      end

      def self.socket
        return unless connection_config.present?

        connection_config[:socket]
      end

      def self.db_host
        return unless connection_config.present?

        connection_config[:host]
      end

      def self.database
        return unless connection_config.present?

        connection_config[:database]
      end

      ## 
      # Insert trace string as traceparent to sql statement
      # Not insert if:
      #   there is no valid current trace context
      #   current trace context is not sampled
      # 
      def self.traceparent
        span_context = ::OpenTelemetry::Trace.current_span.context
        return '' if span_context == ::OpenTelemetry::Trace::SpanContext::INVALID

        trace_flag = span_context.trace_flags.sampled? ? '01': '00'
        return '' if trace_flag == '00'

        format(
          '00-%<trace_id>s-%<span_id>s-%<trace_flags>.2d',
          trace_id: span_context.hex_trace_id,
          span_id: span_context.hex_span_id,
          trace_flags: trace_flag)
      rescue NameError => e
        SolarWindsAPM.logger.error {"[#{name}/#{__method__}] Couldn't find OpenTelemetry. Error: #{e.message}"}
      end

      if Gem::Version.new(ActiveRecord::VERSION::STRING) < Gem::Version.new('6.1')
        def self.connection_config
          return if marginalia_adapter.pool.nil?

          marginalia_adapter.pool.spec.config
        end
      else
        def self.connection_config
          # `pool` might be a NullPool which has no db_config
          return unless marginalia_adapter.pool.respond_to?(:db_config)

          marginalia_adapter.pool.db_config.configuration_hash
        end
      end

      def self.inline_annotations
        Thread.current[:marginalia_inline_annotations] ||= []
      end
    end
  end
end
