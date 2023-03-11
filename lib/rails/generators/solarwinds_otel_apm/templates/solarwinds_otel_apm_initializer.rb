# frozen_string_literal: true

# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

# SolarWindsOTelAPM Configuration for the Ruby Agent aka solarwinds_apm gem
# https://cloud.solarwinds.com/
#
# More information on configuring the Ruby Agent can be found here:
# https://documentation.solarwinds.com/en/success_center/swaas/default.htm#cshid=config-ruby-agent
#
# The initial settings in this file represent the defaults

if defined?(SolarWindsOTelAPM::Config)

  # :service_key, :hostname_alias, :http_proxy, and :debug_level
  # are startup settings and can't be changed afterwards.

  #
  # Set SW_APM_SERVICE_KEY
  # This setting will be overridden if SW_APM_SERVICE_KEY is set as an environment variable.
  # This is a required setting. If the service key is not set here it needs to be set as environment variable.
  #
  # The service key is a combination of the API token plus a service name.
  # E.g.: 0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my_service
  #
  # SolarWindsOTelAPM::Config[:service_key] = '0123456789abcde0123456789abcde0123456789abcde0123456789abcde1234:my_service'

  #
  # Set SW_APM_HOSTNAME_ALIAS
  # This setting will be overridden if SW_APM_HOSTNAME_ALIAS is set as an environment variable
  #
  # SolarWindsOTelAPM::Config[:hostname_alias] = 'alias_name'

  #
  # Set Proxy for SolarWinds   # This setting will be overridden if SW_APM_PROXY is set as an environment variable.
  #
  # Please configure http_proxy if a proxy needs to be used to communicate with
  # the SolarWinds APM collector.
  # The format should either be http://<proxyHost>:<proxyPort> for a proxy
  # server that does not require authentication, or
  # http://<username>:<password>@<proxyHost>:<proxyPort> for a proxy server that
  # requires basic authentication.
  #
  # Note that while HTTP is the only type of connection supported, the traffic
  # to SolarWinds is still encrypted using SSL/TLS.
  #
  # It is recommended to configure the proxy in this file or as SW_APM_PROXY
  # environment variable. However, the agent's underlying network library will
  # use a system-wide proxy defined in the environment variables grpc_proxy,
  # https_proxy or http_proxy if no SolarWindsOTelAPM-specific configuration is set.
  # Please refer to gRPC environment variables for more information.
  #
  # SolarWindsOTelAPM::Config[:http_proxy] = http://<proxyHost>:<proxyPort>

  #
  # Set SW_APM_DEBUG_LEVEL
  # This setting will be overridden if SW_APM_DEBUG_LEVEL is set as an environment variable.
  #
  # It sets the log level and takes the following values:
  # -1 disabled, 0 fatal, 1 error, 2 warning, 3 info (the default), 4 debug low, 5 debug medium, 6 debug high.
  # Values out of range (< -1 or > 6) are ignored and the log level is set to the default (info).
  #
  SolarWindsOTelAPM::Config[:debug_level] = 3

  #
  # :debug_level will be used in the c-extension of the gem and also mapped to the
  # Ruby logger as DISABLED, FATAL, ERROR, WARN, INFO, or DEBUG
  # The Ruby logger can afterwards be changed to a different level, e.g:
  # SolarWindsOTelAPM.logger.level = Logger::INFO

  #
  # Set SW_APM_GEM_VERBOSE
  # This setting will be overridden if SW_APM_GEM_VERBOSE is set as an environment variable
  #
  # On startup the components that are being instrumented will be reported if this is set to true.
  # If true and the log level is 4 or higher this may create extra debug log messages
  #
  SolarWindsOTelAPM::Config[:verbose] = false

  #
  # Turn Tracing on or off
  #
  # By default tracing is set to :enabled, the other option is :disabled.
  # :enabled means that sampling will be done according to the current
  # sampling rate and metrics are reported.
  # :disabled means that there is no sampling and metrics are not reported.
  #
  # The values :always and :never are deprecated
  #
  SolarWindsOTelAPM::Config[:tracing_mode] = :enabled

  #
  # Turn Trigger Tracing on or off
  #
  # By default trigger tracing is :enabled, the other option is :disabled.
  # It allows to use the X-Trace-Options header to force a request to be
  # traced (within rate limits set for trigger tracing)
  #
  SolarWindsOTelAPM::Config[:trigger_tracing_mode] = :enabled

  #
  # Trace Context in Logs
  #
  # Configure if and when the Trace ID should be included in application logs.
  # Common Ruby and Rails loggers are auto-instrumented, so that they can include
  # the current Trace ID in log messages.
  #
  # The added string will look like:
  # "trace_id=7435a9fe510ae4533414d425dadf4e18 span_id=49e60702469db05f trace_flags=00"
  #
  # The following options are available:
  # :never    (default)
  # :sampled  only include the Trace ID of sampled requests
  # :traced   include the Trace ID for all traced requests
  # :always   always add a Trace ID, it will be
  #           "trace_id=00000000000000000000000000000000 span_id=0000000000000000 trace_flags=00"
  #           when there is no tracing context.
  #
  SolarWindsOTelAPM::Config[:log_traceId] = :never

  #
  # Trace Context in Queries (sql only)
  #
  # Configure to add the trace context to sql queries so that queries and
  # transactions can be linked in the SolarWinds dashboard
  #
  # This option can add a small overhead for queries that use prepared
  # statements as those statements will be recompiled whenever the trace context
  # is added (about 10% of the requests)
  #
  # the options are:
  # - true   (default) no trace context is added
  # - false  the tracecontext is added as comment to the start of the query, e.g:
  #          "/*traceparent='00-268748089f148899e29fc5711aca7760-7c6c704dcbba6682-01'*/SELECT `widgets`.* FROM `widgets` WHERE ..."
  #
  SolarWindsOTelAPM::Config[:tag_sql] = false

  #
  # Sanitize SQL Statements
  #
  # The SolarWindsOTelAPM Ruby client has the ability to sanitize query literals
  # from SQL statements.  By default this is enabled.  Disable to
  # collect and report query literals to SolarWindsOTelAPM.
  #
  SolarWindsOTelAPM::Config[:sanitize_sql] = true
  SolarWindsOTelAPM::Config[:sanitize_sql_regexp] = '(\'[^\']*\'|\d*\.\d+|\d+|NULL)'
  SolarWindsOTelAPM::Config[:sanitize_sql_opts]   = Regexp::IGNORECASE

  #
  # Prepend Domain to Transaction Name
  #
  # If this is set to `true` transaction names will be composed as
  # `my.host.com/controller.action` instead of `controller.action`.
  # This configuration applies to all transaction names, whether deduced by the
  # instrumentation or implicitly set.
  #
  SolarWindsOTelAPM::Config[:transaction_name][:prepend_domain] = false

  #
  # Do Not Trace - DNT
  #
  # DEPRECATED
  # Please comment out if no filtering is desired, e.g. your static
  # assets are served by the web server and not the application
  #
  # This configuration allows creating a regexp for paths that should be excluded
  # from solarwinds_apm processing.
  #
  # For example:
  # - static assets that aren't served by the web server, or
  # - healthcheck endpoints that respond to a heart beat.
  #
  # :dnt_regexp is the regular expression that is applied to the incoming path
  # to determine whether the request should be measured and traced or not.
  #
  # :dnt_opts can be commented out, nil, or Regexp::IGNORECASE
  #
  # The matching happens before routes are applied.
  # The path originates from the rack layer and is retrieved as follows:
  #   req = ::Rack::Request.new(env)
  #   path = URI.unescape(req.path)
  #
  SolarWindsOTelAPM::Config[:dnt_regexp] = '\.(jpg|jpeg|gif|png|ico|css|zip|tgz|gz|rar|bz2|pdf|txt|tar|wav|bmp|rtf|js|flv|swf|otf|eot|ttf|woff|woff2|svg|less)(\?.+){0,1}$'
  SolarWindsOTelAPM::Config[:dnt_opts] = Regexp::IGNORECASE

  #
  # GraphQL
  #
  # Enable tracing for GraphQL.
  # (true | false, default: true)
  SolarWindsOTelAPM::Config[:graphql][:enabled] = true
  # Replace query arguments with a '?' when sent with a trace.
  # (true | false, default: true)
  SolarWindsOTelAPM::Config[:graphql][:sanitize] = true
  # Remove comments from queries when sent with a trace.
  # (true | false, default: true)
  SolarWindsOTelAPM::Config[:graphql][:remove_comments] = true
  # Create a transaction name by combining
  # "query" or "mutation" with the first word of the query.
  # This overwrites the default transaction name, which is a combination of
  # controller + action and would be the same for all graphql queries.
  # (true | false, default: true)
  SolarWindsOTelAPM::Config[:graphql][:transaction_name] = true

  #
  # Rack::Cache
  #
  # Create a transaction name like `rack-cache.<cache-store>`,
  # e.g. `rack-cache.memcached`
  # This can reduce the number of transaction names, when many requests are
  # served directly from the cache without hitting a controller action.
  # When set to `false` the path will be used for the transaction name.
  #
  SolarWindsOTelAPM::Config[:rack_cache] = { transaction_name: true }

  #
  # Transaction Settings
  #
  # Use this configuration to add exceptions to the global tracing mode and
  # disable/enable metrics and traces for certain transactions.
  #
  # Currently allowed hash keys:
  # :url to apply listed filters to urls.
  #      The matching of settings to urls happens before routes are applied.
  #      The url is extracted from the env argument passed to rack: `env['PATH_INFO']`
  #
  # and the hashes within the :url list either:
  #   :extensions  takes an array of strings for filtering (not regular expressions!)
  #   :tracing     defaults to :disabled, can be set to :enabled to override
  #              the global :disabled setting
  # or:
  #   :regexp      is a regular expression that is applied to the incoming path
  #   :opts        (optional) nil(default) or Regexp::IGNORECASE (options for regexp)
  #   :tracing     defaults to :disabled, can be set to :enabled to override
  #              the global :disabled setting
  #
  # Be careful not to add too many :regexp configurations as they will slow
  # down execution.
  #
  SolarWindsOTelAPM::Config[:transaction_settings] = {
    url: [
      #   {
      #     extensions: %w['long_job'],
      #     tracing: :disabled
      #   },
      #   {
      #     regexp: '^.*\/long_job\/.*$',
      #     opts: Regexp::IGNORECASE,
      #     tracing: :disabled
      #   },
      #   {
      #     regexp: /batch/,
      #   }
    ]
  }

  #
  # Rails Exception Logging
  #
  # In Rails, raised exceptions with rescue handlers via
  # <tt>rescue_from</tt> are not reported to the SolarWinds   # dashboard by default.  Setting this value to true will
  # report all raised exceptions regardless.
  #
  SolarWindsOTelAPM::Config[:report_rescued_errors] = false

  #
  # EC2 Metadata Fetching Timeout
  #
  # The timeout can be in the range 0 - 3000 (milliseconds)
  # Setting to 0 milliseconds effectively disables fetching from
  # the metadata URL (not waiting), and should only be used if
  # not running on EC2 / Openstack to minimize agent start up time.
  #
  SolarWindsOTelAPM::Config[:ec2_metadata_timeout] = 1000


  #############################################
  ## SETTINGS FOR OPENTELEMTRY COMPONENT     ##
  #############################################

  SolarWindsOTelAPM::Config[:otel_propagator]   = ''

  SolarWindsOTelAPM::Config[:otel_exporter]     = ''

  SolarWindsOTelAPM::Config[:otel_sampler]      = ''

  SolarWindsOTelAPM::Config[:otel_processor]    = ''

  SolarWindsOTelAPM::Config[:service_name]      = ''

  SolarWindsOTelAPM::Config[:otel_response_propagator]    = ''

  #############################################
  ## SETTINGS FOR INDIVIDUAL GEMS/FRAMEWORKS ##
  #############################################

  #
  # Bunny Controller and Action
  #
  # The bunny (Rabbitmq) instrumentation can optionally report
  # Controller and Action values to allow filtering of bunny
  # message handling in # the UI.  Use of Controller and Action
  # for filters is temporary until the UI is updated with
  # additional filters.
  #
  # These values identify which properties of
  # Bunny::MessageProperties to report as Controller
  # and Action.  The defaults are to report :app_id (as
  # Controller) and :type (as Action).  If these values
  # are not specified in the publish, then nothing
  # will be reported here.
  #
  SolarWindsOTelAPM::Config[:bunnyconsumer][:controller] = :app_id
  SolarWindsOTelAPM::Config[:bunnyconsumer][:action] = :type

  #
  # Enabling/Disabling Instrumentation
  #
  # If you're having trouble with one of the instrumentation libraries, they
  # can be individually disabled here by setting the :enabled
  # value to false.
  #
  # :enabled settings are read on startup and can't be changed afterwards
  #
  SolarWindsOTelAPM::Config[:action_controller][:enabled] = true
  SolarWindsOTelAPM::Config[:action_controller_api][:enabled] = true
  SolarWindsOTelAPM::Config[:action_view][:enabled] = true
  SolarWindsOTelAPM::Config[:active_record][:enabled] = true
  SolarWindsOTelAPM::Config[:bunnyclient][:enabled] = true
  SolarWindsOTelAPM::Config[:bunnyconsumer][:enabled] = true
  SolarWindsOTelAPM::Config[:curb][:enabled] = true
  SolarWindsOTelAPM::Config[:dalli][:enabled] = true
  SolarWindsOTelAPM::Config[:delayed_jobclient][:enabled] = true
  SolarWindsOTelAPM::Config[:delayed_jobworker][:enabled] = true
  SolarWindsOTelAPM::Config[:excon][:enabled] = true
  SolarWindsOTelAPM::Config[:faraday][:enabled] = true
  SolarWindsOTelAPM::Config[:grpc_client][:enabled] = true
  SolarWindsOTelAPM::Config[:grpc_server][:enabled] = true
  SolarWindsOTelAPM::Config[:grape][:enabled] = true
  SolarWindsOTelAPM::Config[:httpclient][:enabled] = true
  SolarWindsOTelAPM::Config[:memcached][:enabled] = true
  SolarWindsOTelAPM::Config[:mongo][:enabled] = true
  SolarWindsOTelAPM::Config[:moped][:enabled] = true
  SolarWindsOTelAPM::Config[:nethttp][:enabled] = true
  SolarWindsOTelAPM::Config[:padrino][:enabled] = true
  SolarWindsOTelAPM::Config[:rack][:enabled] = true
  SolarWindsOTelAPM::Config[:redis][:enabled] = true
  SolarWindsOTelAPM::Config[:resqueclient][:enabled] = true
  SolarWindsOTelAPM::Config[:resqueworker][:enabled] = true
  SolarWindsOTelAPM::Config[:rest_client][:enabled] = true
  SolarWindsOTelAPM::Config[:sequel][:enabled] = true
  SolarWindsOTelAPM::Config[:sidekiqclient][:enabled] = true
  SolarWindsOTelAPM::Config[:sidekiqworker][:enabled] = true
  SolarWindsOTelAPM::Config[:sinatra][:enabled] = true
  SolarWindsOTelAPM::Config[:typhoeus][:enabled] = true

  #
  # Argument logging
  #
  #
  # For http requests:
  # By default the query string parameters are included in the URLs reported.
  # Set :log_args to false and instrumentation will stop collecting
  # and reporting query arguments from URLs.
  #
  SolarWindsOTelAPM::Config[:bunnyconsumer][:log_args] = true
  SolarWindsOTelAPM::Config[:curb][:log_args] = true
  SolarWindsOTelAPM::Config[:excon][:log_args] = true
  SolarWindsOTelAPM::Config[:httpclient][:log_args] = true
  SolarWindsOTelAPM::Config[:mongo][:log_args] = true
  SolarWindsOTelAPM::Config[:nethttp][:log_args] = true
  SolarWindsOTelAPM::Config[:rack][:log_args] = true
  SolarWindsOTelAPM::Config[:resqueclient][:log_args] = true
  SolarWindsOTelAPM::Config[:resqueworker][:log_args] = true
  SolarWindsOTelAPM::Config[:sidekiqclient][:log_args] = true
  SolarWindsOTelAPM::Config[:sidekiqworker][:log_args] = true
  SolarWindsOTelAPM::Config[:typhoeus][:log_args] = true

  #
  # Enabling/Disabling Backtrace Collection
  #
  # Instrumentation can optionally collect backtraces as they collect
  # performance metrics.  Note that this has a negative impact on
  # performance but can be useful when trying to locate the source of
  # a certain call or operation.
  #
  SolarWindsOTelAPM::Config[:action_controller][:collect_backtraces] = true
  SolarWindsOTelAPM::Config[:action_controller_api][:collect_backtraces] = true
  SolarWindsOTelAPM::Config[:action_view][:collect_backtraces] = true
  SolarWindsOTelAPM::Config[:active_record][:collect_backtraces] = true
  SolarWindsOTelAPM::Config[:bunnyclient][:collect_backtraces] = false
  SolarWindsOTelAPM::Config[:bunnyconsumer][:collect_backtraces] = false
  SolarWindsOTelAPM::Config[:curb][:collect_backtraces] = true
  SolarWindsOTelAPM::Config[:dalli][:collect_backtraces] = false
  SolarWindsOTelAPM::Config[:delayed_jobclient][:collect_backtraces] = false
  SolarWindsOTelAPM::Config[:delayed_jobworker][:collect_backtraces] = false
  SolarWindsOTelAPM::Config[:excon][:collect_backtraces] = true
  SolarWindsOTelAPM::Config[:faraday][:collect_backtraces] = false
  SolarWindsOTelAPM::Config[:grape][:collect_backtraces] = true
  SolarWindsOTelAPM::Config[:grpc_client][:collect_backtraces] = false
  SolarWindsOTelAPM::Config[:grpc_server][:collect_backtraces] = false
  SolarWindsOTelAPM::Config[:httpclient][:collect_backtraces] = true
  SolarWindsOTelAPM::Config[:memcached][:collect_backtraces] = false
  SolarWindsOTelAPM::Config[:mongo][:collect_backtraces] = true
  SolarWindsOTelAPM::Config[:moped][:collect_backtraces] = true
  SolarWindsOTelAPM::Config[:nethttp][:collect_backtraces] = true
  SolarWindsOTelAPM::Config[:padrino][:collect_backtraces] = true
  SolarWindsOTelAPM::Config[:rack][:collect_backtraces] = true
  SolarWindsOTelAPM::Config[:redis][:collect_backtraces] = false
  SolarWindsOTelAPM::Config[:resqueclient][:collect_backtraces] = true
  SolarWindsOTelAPM::Config[:resqueworker][:collect_backtraces] = true
  SolarWindsOTelAPM::Config[:rest_client][:collect_backtraces] = true
  SolarWindsOTelAPM::Config[:sequel][:collect_backtraces] = true
  SolarWindsOTelAPM::Config[:sidekiqclient][:collect_backtraces] = false
  SolarWindsOTelAPM::Config[:sidekiqworker][:collect_backtraces] = false
  SolarWindsOTelAPM::Config[:sinatra][:collect_backtraces] = true
  SolarWindsOTelAPM::Config[:typhoeus][:collect_backtraces] = false

end
