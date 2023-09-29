# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

# This file is for loading support library

require_relative './support/logger_formatter'
require_relative './support/logging_log_event'
require_relative './support/lumberjack_formatter'
require_relative './support/transaction_cache'
require_relative './support/transaction_settings'
require_relative './support/oboe_tracing_mode'
require_relative './support/txn_name_manager'
require_relative './support/utils'
require_relative './support/x_trace_options'

if SolarWindsAPM::Config[:tag_sql]
  if defined?(::Rails)
    if ::Rails.version < '7'
      require_relative './support/swomarginalia/railtie'
    elsif ::Rails.version >= '7'
      # User has to define in their config/environments:
      # config.active_record.query_log_tags = [ 
      #   { 
      #     tracecontext: -> { 
      #       SolarWindsAPM::SWOMarginalia::Comment.traceparent 
      #     } 
      #   }
      # ]
      SolarWindsAPM.logger.info {"In Rails 7, tag tracecontext on a query by including SolarWindsAPM::SWOMarginalia::Comment.traceparent as function in config.active_record.query_log_tags."}
      SolarWindsAPM.logger.info {"For more information, please check https://api.rubyonrails.org/classes/ActiveRecord/QueryLogs.html"}
      require_relative './support/swomarginalia/comment'
    end
  elsif defined?(::ActiveRecord)
    require_relative './support/swomarginalia/load_swomarginalia'
    SolarWindsAPM::SWOMarginalia::LoadSWOMarginalia.insert
  end
end
