require_relative './comment'

module SolarWindsOTelAPM
  module SWOMarginalia
    mattr_accessor :application_name

    module ActiveRecordInstrumentation
      def self.included(instrumented_class)
        instrumented_class.class_eval do
          if instrumented_class.method_defined?(:execute)
            alias_method :execute_without_swo, :execute
            alias_method :execute, :execute_with_swo
          end

          if instrumented_class.private_method_defined?(:execute_and_clear)
            alias_method :execute_and_clear_without_swo, :execute_and_clear
            alias_method :execute_and_clear, :execute_and_clear_with_swo
          else
            is_mysql2 = defined?(ActiveRecord::ConnectionAdapters::Mysql2Adapter) &&
                        instrumented_class == ActiveRecord::ConnectionAdapters::Mysql2Adapter
            # Dont instrument exec_query on mysql2 as it calls execute internally
            unless is_mysql2
              if instrumented_class.method_defined?(:exec_query)
                alias_method :exec_query_without_swo, :exec_query
                alias_method :exec_query, :exec_query_with_swo
              end
            end

            is_postgres = defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) &&
                          instrumented_class == ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
            # Instrument exec_delete and exec_update since they don't call
            # execute internally
            if is_postgres
              if instrumented_class.method_defined?(:exec_delete)
                alias_method :exec_delete_without_swo, :exec_delete
                alias_method :exec_delete, :exec_delete_with_swo
              end
              if instrumented_class.method_defined?(:exec_update)
                alias_method :exec_update_without_swo, :exec_update
                alias_method :exec_update, :exec_update_with_swo
              end
            end
          end
        end
      end

      def annotate_sql(sql)
        sql = remove_previous_traceparent(sql)

        SWOMarginalia::Comment.update_adapter!(self)            # switch to current sql adapter
        comment = SWOMarginalia::Comment.construct_comment      # comment will include traceparent
        if comment.present? && !sql.include?(comment)
          sql = if SWOMarginalia::Comment.prepend_comment
                  "/*#{comment}*/ #{sql}"
                else
                  "#{sql} /*#{comment}*/"
                end
        end

        inline_comment = SWOMarginalia::Comment.construct_inline_comment # this is for customized_swo_inline_annotations (user-defined value)
        if inline_comment.present? && !sql.include?(inline_comment)
          sql = if SWOMarginalia::Comment.prepend_comment
                  "/*#{inline_comment}*/ #{sql}"
                else
                  "#{sql} /*#{inline_comment}*/"
                end
        end

        sql
      end

      # Sample string for pattern: "SELECT 1; /* traceparent=1234567890abcdef */"
      def remove_previous_traceparent(sql)
        sql_regex = /\/\*\s*traceparent=.*\*\/\s*/.freeze
        sql.gsub(sql_regex, '')
      end

      def execute_with_swo(sql, *args)
        execute_without_swo(annotate_sql(sql), *args)
      end
      ruby2_keywords :execute_with_swo if respond_to?(:ruby2_keywords, true)

      def exec_query_with_swo(sql, *args, **options)
        options[:prepare] ||= false
        exec_query_without_swo(annotate_sql(sql), *args, **options)
      end

      def exec_delete_with_swo(sql, *args)
        exec_delete_without_swo(annotate_sql(sql), *args)
      end
      ruby2_keywords :exec_delete_with_swo if respond_to?(:ruby2_keywords, true)

      def exec_update_with_swo(sql, *args)
        exec_update_without_swo(annotate_sql(sql), *args)
      end
      ruby2_keywords :exec_update_with_swo if respond_to?(:ruby2_keywords, true)

      def execute_and_clear_with_swo(sql, *args, &block)
        execute_and_clear_without_swo(annotate_sql(sql), *args, &block)
      end
      ruby2_keywords :execute_and_clear_with_swo if respond_to?(:ruby2_keywords, true)
    end

    module ActionControllerInstrumentation
      def self.included(instrumented_class)
        instrumented_class.class_eval do
          if respond_to?(:around_action)
            around_action :record_query_comment
          else
            around_filter :record_query_comment
          end
        end
      end

      def record_query_comment
        SWOMarginalia::Comment.update!(self)
        yield
      ensure
        SWOMarginalia::Comment.clear!
      end
    end

    def self.with_annotation(comment, &block)
      SWOMarginalia::Comment.inline_annotations.push(comment)
      block.call if block.present?
    ensure
      SWOMarginalia::Comment.inline_annotations.pop
    end
  end
end
