# SolarWindsOTelAPM Gem Configuration

## Environment Variables

The following environment variables are detected by the solarwinds_otel_apm gem and affect how the gem functions.

### General

Name | Description | Default
---- | ----------- | -------
`SW_APM_SERVICE_KEY` | API token + service name combination, mandatory for metrics and traces to show in the dashboard |
`SW_APM_GEM_VERBOSE` | sets the verbose flag (`SolarWindsOTelAPM::Config[:verbose]`) early in the gem loading process which may output valuable information | `false`
`SW_APM_COLLECTOR` | ingestion endpoint the library connects and exports data to. It should be defined using the format host:port. | apm.collector.cloud.solarwinds.com:443
`SW_APM_TRUSTEDPATH` | The library uses the trusted CA certificates installed in the system to verify the TLS connection to the collector. To override the default, define the trusted certificate path configuration option with an absolute path to a specific trusted certificate file in PEM format.
`SW_APM_DEBUG_LEVEL` | level at which log messages will be written to log file (0-6) | 3
`SW_APM_AUTO_CONFIGURE` | By default the custom distro is configured to work out-of-the-box with all automatic instrumentation libraries enabled. Set this to false to custom initialize the distro with configuration options for instrumentation, see (link to in-code configuration section) for details. | `true`


## In-code Configuration

SolarWindsOTelAPM allows the in-code configuration for setting the options of otel instrumentations. More information about what option can be configured, please consult [opentelemetry-ruby-contrib](https://github.com/open-telemetry/opentelemetry-ruby-contrib/tree/main/instrumentation) pages.

Below example sets Dalli otel instrumentation to disable (e.g. `{:enabled: false}`); and sets Rack otel instrumentation to have header1 and header2 to allowed request headers. More information about Rack's [allowed_request_headers](https://github.com/open-telemetry/opentelemetry-ruby-contrib/blob/main/instrumentation/rack/lib/opentelemetry/instrumentation/rack/instrumentation.rb#L23).

Note: in order to set the customized configuration, please set `SW_APM_AUTO_CONFIGURE=false`
```ruby
require 'solarwinds_otel_apm'
SolarWindsOTelAPM::OTelConfig.initialize_with_config do |config|
  config["OpenTelemetry::Instrumentation::Dalli"] = {:enabled: false}
  config["OpenTelemetry::Instrumentation::Rack"]  = {:allowed_request_headers: ['header1', 'header2']}
end
```

## SolarWindsOTelAPM config file

`SolarWindsOTelAPM::Config` is a nested hash used by the solarwinds_apm gem to store preferences and switches.

See [this Rails generator template file](https://github.com/solarwindscloud/swotel-ruby/blob/main/lib/rails/generators/solarwinds_otel_apm/templates/solarwinds_otel_apm_initializer.rb) for documentation on all of the supported values.

### Transaction Filtering (`[:transaction_settings]`)

Sample configuration:
```ruby
SolarWindsOTelAPM::Config[:transaction_settings] = [
  {
    extensions: %w[long_job],
    tracing: :disabled
  },
  {
    regexp: '^.*\/long_job\/.*$',
    opts: Regexp::IGNORECASE,
    tracing: :disabled
  },
  {
    regexp: /batch/,
  }
]
```