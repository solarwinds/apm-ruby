# frozen_string_literal: true

require_relative 'comment'

module SolarWindsAPM
  module SWOMarginalia
    module Annotation
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
  end
end
