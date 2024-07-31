# frozen_string_literal: true

module SolarWindsAPM
  module SWOMarginalia
    module Formatter
      def tag_content
        comment = super
        comment.tr!(':', '=')
        comment
      end
    end
  end
end

# Prepend the Formatter module to the singleton class of ActiveRecord::QueryLogs
if defined?(ActiveRecord::QueryLogs)
  class << ActiveRecord::QueryLogs
    prepend SolarWindsAPM::SWOMarginalia::Formatter
  end
end
