# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.
#
# This file is for loading support library
#

require_relative './support/logger_formatter'
require_relative './support/logging_log_event'
require_relative './support/lumberjack_formatter'
require_relative './support/transaction_cache'
require_relative './support/transaction_settings'
require_relative './support/oboe_tracing_mode'
require_relative './support/txn_name_manager'
require_relative './support/transformer'
require_relative './support/x_trace_options'

if defined?(::Rails)
  if ::Rails.version < '7'
    require_relative './support/railtie'
  elsif ::Rails.version >= '7'
    # User has to define in their config/environments:
    # config.active_record.query_log_tags = [ 
    #   { 
    #     tracecontext: -> { 
    #       SolarWindsOTelAPM::SWOMarginalia::Comment.traceparent 
    #     } 
    #   }
    # ]
    require_relative './support/swomarginalia/comment'
  end
end
