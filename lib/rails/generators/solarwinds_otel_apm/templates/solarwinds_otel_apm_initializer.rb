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
  # EC2 Metadata Fetching Timeout
  #
  # The timeout can be in the range 0 - 3000 (milliseconds)
  # Setting to 0 milliseconds effectively disables fetching from
  # the metadata URL (not waiting), and should only be used if
  # not running on EC2 / Openstack to minimize agent start up time.
  #
  SolarWindsOTelAPM::Config[:ec2_metadata_timeout] = 1000

  #
  # Trigger Trace Mode
  # 
  # Trace options is a custom HTTP header X-Trace-Options that can be set on a request to carry additional information 
  # to the agents, one such option being trigger-trace which we’ll call a trigger trace request.
  #
  SolarWindsOTelAPM::Config[:trigger_tracing_mode] = 'enabled'

  #
  # Argument logging
  #
  # For http requests:
  # By default the query string parameters are included in the URLs reported.
  # Set :log_args to false and instrumentation will stop collecting
  # and reporting query arguments from URLs.
  #
  SolarWindsOTelAPM::Config[:log_args] = true
end
