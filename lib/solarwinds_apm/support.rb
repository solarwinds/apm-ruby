# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

# This file is for loading support library

require_relative 'support/logger_formatter'
require_relative 'support/logging_log_event'
require_relative 'support/lumberjack_formatter'
require_relative 'support/transaction_cache'
require_relative 'support/transaction_settings'
require_relative 'support/oboe_tracing_mode'
require_relative 'support/txn_name_manager'
require_relative 'support/utils'
require_relative 'support/x_trace_options'
require_relative 'support/support_report'

if SolarWindsAPM::Config[:tag_sql]
  if defined?(Rails)

    if Rails.version >= '7'
      SolarWindsAPM.logger.info do
        'In Rails 7, tag tracecontext on a query by including SolarWindsAPM::SWOMarginalia::Comment.traceparent as a function in config.active_record.query_log_tags. ' \
          'In Rails >= 7.1, change the default formatter to sqlcommenter via config.active_record.query_log_tags_format = :sqlcommenter for the correct format. ' \
          'For more info, visit https://api.rubyonrails.org/classes/ActiveRecord/QueryLogs.html'
      end
      require_relative 'support/swomarginalia/comment'
    end

    if Rails.version < '7'
      require_relative 'support/swomarginalia/railtie'
    elsif Rails.version >= '7' && Rails.version < '7.1'
      require_relative 'support/swomarginalia/formatter'
    end
  elsif defined?(ActiveRecord)
    require_relative 'support/swomarginalia/load_swomarginalia'
    SolarWindsAPM::SWOMarginalia::LoadSWOMarginalia.insert
  end
end
