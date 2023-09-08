# Configuration

By default all applicable instrumentations are enabled. The only required configuration is the service key, so a minimal example to get started is:
```bash
export SW_APM_SERVICE_KEY=<set-service-key-here>
ruby application.rb
```

Configuration can be set several ways, with the following precedence:

`in-code > environmental variable > configuration file > default`

## In-code Configuration

Many OpenTelemetry instrumenter configurations can be set within the `SolarWindsAPM::OTelConfig.initialize_with_config` block, which overrides the same options set via environment variable or configuration file. Please consult the individual [instrumenter](https://github.com/open-telemetry/opentelemetry-ruby-contrib/tree/main/instrumentation) README pages for the options available.

**Important**: this feature is only enabled if auto-config is disabled via `SW_APM_AUTO_CONFIGURE=false`.

Below is an example that disables Dalli instrumentation and sets the Rack instrumentation to capture certain headers as Span attributes:
```ruby
# note auto-configure must be disabled, e.g.
# export SW_APM_AUTO_CONFIGURE=false

require 'solarwinds_apm'

SolarWindsAPM::OTelConfig.initialize_with_config do |config|
  config["OpenTelemetry::Instrumentation::Dalli"] = {:enabled => false}
  config["OpenTelemetry::Instrumentation::Rack"]  = {:allowed_request_headers => ['header1', 'header2']}
end
```

## Environment Variables

Settings specific to `solarwinds_apm` are prefixed by `SW_APM_` and described in the [Reference](#reference) section. Standard OpenTelemetry environment variables that impact this library's functionality are noted below.

### Exporter

The default exporter is `solarwinds` which communicates with the SolarWinds Observability backend. The standard OTLP exporter can also be configured in via `OTEL_TRACES_EXPORTER`, please ensure `solarwinds` is included.

Example:
```bash
export OTEL_TRACES_EXPORTER="solarwinds,otlp"
```

### Service Name

By default the service name portion of the service key is used, e.g. `my-service` if the service key is `SW_APM_SERVICE_KEY=api-token:my-service`. If the `OTEL_SERVICE_NAME` or `OTEL_RESOURCE_ATTRIBUTES` environment variable is used to specify a service name, it will take precedence over the default.

```bash
export SW_APM_SERVICE_KEY=<api-token>:foo
export OTEL_SERVICE_NAME=bar

# service name for instrumented app will be "bar"
ruby application.rb
```

## Configuration File

On startup, the library looks for the configuration file in the following locations under the application's current working directory:

* `config/initializers/solarwinds_apm.rb` for Rails applications, which can be created by running the provided generator:
  ```bash
  bundle exec rails generate solarwinds_apm:install
  ```
* `solarwinds_apm_config.rb` for non-Rails applications

The default location can be overridden via environment variable `SW_APM_CONFIG_RUBY`:
```bash
export SW_APM_CONFIG_RUBY=config/file/location.rb
```

The configuration file should be Ruby code that sets key/values in the hash exposed by `SolarWindsAPM::Config`. The bundled [Rails generator template file](https://github.com/solarwindscloud/swotel-ruby/blob/main/lib/rails/generators/solarwinds_apm/templates/solarwinds_apm_initializer.rb) serves as an example of the supported values, see also the [Reference](#reference) section.

### Transaction Filtering

Specific transactions can be disabled from tracing (suppressing both spans and metrics) using the `:transaction_settings` configuration. An example that filters out static assets and a message consumer:
```ruby
SolarWindsAPM::Config[:transaction_settings] = [
  {
    regexp: '\.(css|js|png)$',
    opts: Regexp::IGNORECASE,
    tracing: :disabled
  },
  {
    regexp: 'CONSUMER:mytopic process',
    tracing: :disabled
  }
]
```

## Reference

Environment Variable | Config File Key | Description | Default
-------------------- | --------------- | ----------- | -------
`SW_APM_AUTO_CONFIGURE` | N/A  | By default the library is configured to work out-of-the-box with all automatic instrumentation libraries enabled. Set this to false to custom initialize the library with configuration options for instrumentation, see [In-code Configuration](#in-code-configuration) for details. | true
`SW_APM_COLLECTOR` | N/A | Override the default collector endpoint to which the library connects and exports data. It should be defined using the format host:port. | apm.collector.cloud.solarwinds.com:443
`SW_APM_CONFIG_RUBY` | N/A | Override the default location for the configuration file. This can be an absolute or relative filename, or the directory under which the `solarwinds_apm_config.rb` file would be looked for. | None
`SW_APM_DEBUG_LEVEL` | `:debug_level` | Set the library's logging level, valid values are 0 through 6 (least to most verbose). | 3
`SW_APM_EC2_METADATA_TIMEOUT` | `:ec2_metadata_timeout` | Timeout for AWS IMDS metadata retrieval in milliseconds. | 1000
`SW_APM_ENABLED` | N/A | Enable/disable the library, setting `false` is an alternative to uninstalling `solarwinds_apm` since it will prevent the library from loading. | true
`SW_APM_PROXY` | `:http_proxy` | Configure an HTTP proxy through which the library connects to the collector. | None
`SW_APM_SERVICE_KEY` | `:service_key` | API token + service name combination, **required**. |
`SW_APM_TAG_SQL` | `:tag_sql` | Enable/disable injecting trace context into supported SQL statements. | false
`SW_APM_TRIGGER_TRACING_MODE` | `:trigger_tracing_mode` | | enable
`SW_APM_TRUSTEDPATH` | N/A | The library uses the host system's default trusted CA certificates to verify the TLS connection to the collector. To override the default, define the trusted certificate path configuration option with an absolute path to a specific trusted certificate file in PEM format. | None
N/A | `:log_args` | Enable/disable the collection of URL query parameters, set to `false` to disable. | `true`
N/A | `:log_traceId` | Configure the insertion of trace context into application logs, setting `:traced` would include the available context fields such as trace_id, span_id into log messages. | `:never`
N/A | `:tracing_mode` | Enable/disable the tracing mode for this service, setting `:disabled` would suppress all trace spans and metrics. | `:enabled`
N/A | `:transaction_settings` | Configure tracing mode per transaction, aka transaction filtering. | None