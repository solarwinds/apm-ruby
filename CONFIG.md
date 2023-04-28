# SolarWindsAPM Gem Configuration

## Environment Variables

The following environment variables are detected by the solarwinds_apm gem and affect how the gem functions.

### General

Name | Description | Default
---- | ----------- | -------
`SW_APM_SERVICE_KEY` | API token + service name combination, mandatory for metrics and traces to show in the dashboard |
`SW_APM_GEM_VERBOSE` | sets the verbose flag (`SolarWindsAPM::Config[:verbose]`) early in the gem loading process which may output valuable information | `false`
`SW_APM_COLLECTOR` | URL for the swo endpoint | 
`SW_APM_TRUSTEDPATH` | directory path for setting the certification to connect appoptics endpoint
`SW_APM_DEBUG_LEVEL` | level at which log messages will be written to log file (0-6) | 3
`SW_APM_AUTO_CONFIGURE` | set the auto/default configuration for solarwinds apm agent | `true`


## In-code Configuration

SolarWindsOTelAPM allows the in-code configuration for setting the options of otel instrumentations. More information about what option can be configured, please consult [opentelemetry-ruby-contrib](https://github.com/open-telemetry/opentelemetry-ruby-contrib/tree/main/instrumentation) pages.

### Example:

Below example sets Dalli otel instrumentation to disable (e.g. `{:enabled: false}`); and sets Rack otel instrumentation to have header1 and header2 to allowed request headers. More information about Rack's [allowed_request_headers](https://github.com/open-telemetry/opentelemetry-ruby-contrib/blob/main/instrumentation/rack/lib/opentelemetry/instrumentation/rack/instrumentation.rb#L23).

Note: in order to set the customized configuration, please set `SW_APM_AUTO_CONFIGURE=false`
```ruby
require 'solarwinds_otel_apm'
SolarWindsOTelAPM::OTelConfig.initialize do |config|
  config["OpenTelemetry::Instrumentation::Dalli"] = {:enabled: false}
  config["OpenTelemetry::Instrumentation::Rack"]  = {:allowed_request_headers: ['header1', 'header2']}
end
```


## SolarWindsAPM config file

`SolarWindsOTelAPM::Config` is a nested hash used by the solarwinds_apm gem to store preferences and switches.

See [this Rails generator template file](https://github.com/librato/ruby-solarwinds/blob/master/lib/rails/generators/solarwinds_apm/templates/sw_apm_initializer.rb) for documentation on all of the supported values.
