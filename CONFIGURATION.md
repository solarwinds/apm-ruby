# Configuration

By default all applicable instrumentations are enabled. The only required configuration is the service key, so a minimal example to get started is:

```bash
export SW_APM_SERVICE_KEY=<set-service-key-here>
```

Configuration can be set several ways, with the following precedence:

`environment variable > programmatic > configuration file > default`

Many OpenTelemetry instrumenter configurations can be set within the `SolarWindsAPM::OTelConfig.initialize_with_config ... end` block, please consult the individual [instrumenter](https://github.com/open-telemetry/opentelemetry-ruby-contrib/tree/main/instrumentation) README pages for the options available. Note that [environment varables](#instrumentation-1) can be used to simply disable an instrumentation and set basic instrumentation options.

## Programmatic Configuration

> [!IMPORTANT]
> this feature is only enabled if auto-config is disabled via `SW_APM_AUTO_CONFIGURE=false`.

### Instrumentation Programmatic Configuration

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

The default `solarwinds` exporter which communicates with the SolarWinds Observability backend is always configured. Additional exporters can be configured via the `OTEL_TRACES_EXPORTER` environment variable. For example, console exporter is part of standard installation and can be enabled via:

```bash
export OTEL_TRACES_EXPORTER=console
```

Other exporters must first be installed and required before loading `solarwinds_apm`. For example, if dependencies are loaded by `Bundler.require`, add the OTLP exporter to the Gemfile:

```ruby
# application dependencies, eg
# gem "rails", "~> 7.0.5", ">= 7.0.5.1"

gem "opentelemetry-exporter-otlp"

# end of Gemfile
gem 'solarwinds_apm'
```

And set the environment variable:

```bash
export OTEL_TRACES_EXPORTER=otlp
```

### Service Name

By default the service name portion of the service key is used, e.g. `my-service` if the service key is `SW_APM_SERVICE_KEY=api-token:my-service`. If the `OTEL_SERVICE_NAME` or `OTEL_RESOURCE_ATTRIBUTES` environment variable is used to specify a service name, it will take precedence over the default.

```bash
export SW_APM_SERVICE_KEY=<api-token>:foo
export OTEL_SERVICE_NAME=bar

# service name for instrumented app will be "bar"
ruby application.rb
```

### Instrumentation Environment Variables

You can use OpenTelemetry Ruby instrumentation environment variables to disable certain instrumentation.
From [instrumentation-base](https://github.com/open-telemetry/opentelemetry-ruby-contrib/blob/opentelemetry-instrumentation-base/v0.22.3/instrumentation/base/lib/opentelemetry/instrumentation/base.rb#L56-L61):
> The instrumention class establishes a convention for disabling an instrumentation
> by environment variable and local configuration. An instrumentation disabled
> by environment variable will take precedence over local config. The
> convention for environment variable name is the library name, upcased with
> '::' replaced by underscores, OPENTELEMETRY shortened to OTEL_{LANG}, and '_ENABLED' appended.
> For example: OTEL_RUBY_INSTRUMENTATION_SINATRA_ENABLED = false.

For example to disable sinatra instrumentation, you can set `OTEL_RUBY_INSTRUMENTATION_SINATRA_ENABLED` to false through

```bash
export OTEL_RUBY_INSTRUMENTATION_SINATRA_ENABLED=false
```

or in your initialization step

```ruby
ENV['OTEL_RUBY_INSTRUMENTATION_SINATRA_ENABLED']='false'
```

Options setup through enviromental variables

> Checks to see if user pass any environment variable that set option for instrumentation.
> By convention, the environment variable will be the instrumentation name upper cased,
> with '::' replaced by underscores, OPENTELEMETRY shortened to OTEL_{LANG} and_CONFIG_OPTS appended.
> For example, the, environment variable name for OpenTelemetry::Instrumentation::Faraday
> will be OTEL_RUBY_INSTRUMENTATION_FARADAY_CONFIG_OPTS. A value of 'peer_service=new_service;'
> will overrides the option set from ::OpenTelemetry::SDK.configure do |c| ... end for faraday.
>
> For array option, simply separate the value by , (e.g. option=a,b,c,d).
> For boolean option, set value by true or false (e.g. option=true).
> For integer, string, enum, set value by string (e.g. option=string).
> Callable option is not allowed to set through environment variable.

For example, to disable db.statement obfuscation in mysql2 instrumentation, set `OTEL_RUBY_INSTRUMENTATION_MYSQL2_CONFIG_OPTS` through

```bash
export OTEL_RUBY_INSTRUMENTATION_MYSQL2_CONFIG_OPTS='db_statement=include;'
```

or in your initialization step

```ruby
ENV['OTEL_RUBY_INSTRUMENTATION_MYSQL2_CONFIG_OPTS'] = 'db_statement=include;'
```

See more details in [instrumentation-base](https://github.com/open-telemetry/opentelemetry-ruby-contrib/blob/opentelemetry-instrumentation-base/v0.22.3/instrumentation/base/lib/opentelemetry/instrumentation/base.rb#L56-L61)

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

The configuration file should be Ruby code that sets key/values in the hash exposed by `SolarWindsAPM::Config`. The bundled [Rails generator template file](https://github.com/solarwinds/apm-ruby/blob/main/lib/rails/generators/solarwinds_apm/templates/solarwinds_apm_initializer.rb) serves as an example of the supported values, see also the [Reference](#reference) section.

## Reference

Environment Variable | Config File Key | Description | Default
-------------------- | --------------- | ----------- | -------
`SW_APM_AUTO_CONFIGURE` | N/A  | By default the library is configured to work out-of-the-box with all automatic instrumentation libraries enabled. Set this to `false` to custom initialize the library with configuration options for instrumentation, see [Programmatic Configuration](#programmatic-configuration) for details. | `true`
`SW_APM_COLLECTOR` | N/A | Override the default collector endpoint to which the library connects and exports data. It should be defined using the format host:port. | `apm.collector.na-01.cloud.solarwinds.com:443`
`SW_APM_CONFIG_RUBY` | N/A | Override the default location for the configuration file. This can be an absolute or relative filename, or the directory under which the `solarwinds_apm_config.rb` file would be looked for. | None
`SW_APM_DEBUG_LEVEL` | `:debug_level` | Set the library's logging level, valid values are -1 through 6 (least to most verbose). <br> Setting -1 disables logging from the library. | 3
`SW_APM_EC2_METADATA_TIMEOUT` | `:ec2_metadata_timeout` | Timeout for AWS IMDS metadata retrieval in milliseconds. | 1000
`SW_APM_ENABLED` | N/A | Enable/disable the library, setting `false` is an alternative to uninstalling `solarwinds_apm` since it will prevent the library from loading. | `true`
`SW_APM_LOG_FILEPATH` | N/A | Configure the log file path for the C extension, e.g. `export SW_APM_LOG_FILEPATH=/path/file_path.log`. If set, messages from the C extension are written to the specified file instead of stderr.  | None
`SW_APM_PROXY` | `:http_proxy` | Configure an HTTP proxy through which the library connects to the collector. | None
`SW_APM_SERVICE_KEY` | `:service_key` | API token and service name in the form of `token:service_name`, **required**. | None
`SW_APM_TAG_SQL` | `:tag_sql` | Enable/disable injecting trace context into supported SQL statements. Set to boolean true or (or string `true` in env var) to enable, see [Tag Query with Trace Context](#tag-query-with-trace-context) for details.| `false`
`SW_APM_TRIGGER_TRACING_MODE` | `:trigger_tracing_mode` | Enable/disable trigger tracing for the service.  Setting to `disabled` may impact DEM visibility into the service. | `enabled`
`SW_APM_TRUSTEDPATH` | N/A | The library uses the host system's default trusted CA certificates to verify the TLS connection to the collector. To override the default, define the trusted certificate path configuration option with an absolute path to a specific trusted certificate file in PEM format. | None
`SW_APM_LAMBDA_PRELOAD_DEPS` | N/A | This option is particularly used in apm-ruby lambda layer for preloading user-defined ruby library, and install opentelemetry instrumentation. | `false`
N/A | `:log_args` | Enable/disable the collection of URL query parameters, set to boolean false to disable. | `true`
N/A | `:log_traceId` | Configure the insertion of trace context into application logs, setting `:traced` would include the available context fields such as trace_id, span_id into log messages. | `:never`
N/A | `:tracing_mode` | Enable/disable the tracing mode for this service, setting `:disabled` would suppress all trace spans and metrics. | `:enabled`
N/A | `:transaction_settings` | Configure tracing mode per transaction, aka transaction filtering. See [Transaction Filtering](#transaction-filtering) for details.| None

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

### Tag Query with Trace Context

You can set the environment variable `SW_APM_TAG_SQL` or configuration file option `:tag_sql` to true to enable appending the current trace context into a database query as a SQL comment. For example:

```console
# query without tag sql
SELECT * FROM SAMPLE_TABLE WHERE user_id = 1;

# query with tag sql
SELECT * FROM SAMPLE_TABLE WHERE user_id = 1; /* traceparent=7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-01 */
```

For Rails < 7 and non-Rails applications, we use a port of [Marginalia](https://github.com/basecamp/marginalia) that patches ActiveRecord to inject the comment.

For Rails >= 7, Marginalia is [integrated into ActiveRecord](https://api.rubyonrails.org/classes/ActiveRecord/QueryLogs.html) so enabling this feature should be done through Rails [configuration](https://guides.rubyonrails.org/v7.0/configuring.html#config-active-record-query-log-tags-enabled). For example:

```ruby
class Application < Rails::Application
  config.active_record.query_log_tags_enabled = true
  config.active_record.query_log_tags = [
    {
      traceparent: -> {
        SolarWindsAPM::SWOMarginalia::Comment.traceparent
      }
    }
  ]
end
```

Note that with Rails >= 7.1 the comment format can be specified via the `config.active_record.query_log_tags_format` option. SolarWinds Observability functionality depends on the default `:sqlcommenter` format, it is not recommended to change this value.
