# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require_relative './comment'

module SolarWindsAPM
  module SWOMarginalia
    mattr_accessor :application_name

    # This ActiveRecordInstrumentation should only work for activerecord < 7.0 since after rails 7
    # this module won't be prepend to activerecord
    module ActiveRecordInstrumentation
      def execute(sql, *args, **options)
        super(annotate_sql(sql), *args, **options)
      end

      # only for postgresql adapter
      def execute_and_clear(sql, *args, **options)
        super(annotate_sql(sql), *args, **options)
      end

      def exec_query(sql, *args, **options)
        super(annotate_sql(sql), *args, **options)
      end

      def exec_delete(sql, *args)
        super(annotate_sql(sql), *args)
      end

      def exec_update(sql, *args)
        super(annotate_sql(sql), *args)
      end

      def annotate_sql(sql)
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

      # We don't want to trace framework caches.
      # Only instrument SQL that directly hits the database.
      def ignore_payload?(name)
        %w[SCHEMA EXPLAIN CACHE].include?(name.to_s)
      end
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
