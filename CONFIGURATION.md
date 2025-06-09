# Configuration

By default all applicable instrumentations are enabled. The only required configuration is the service key, so a minimal example to get started is:

```bash
export SW_APM_SERVICE_KEY=<set-service-key-here>
```

Configuration can be set several ways, with the following precedence:

`environment variable > programmatic > configuration file > default`

## Environment Variables

Settings specific to `solarwinds_apm` are prefixed by `SW_APM_` and described in the [Reference](#reference) section. Standard OpenTelemetry environment variables that impact this library's functionality are noted below.

### Exporter

The default `solarwinds` exporter which communicates with the SolarWinds Observability backend is always configured as OTLP Exporter. Additional exporters can be configured via the `OTEL_TRACES_EXPORTER` environment variable. For example, console exporter is part of standard installation and can be enabled via:

```bash
export OTEL_TRACES_EXPORTER=console
```

Other exporters (e.g. Jaeger) must first be installed and required before loading `solarwinds_apm`. For example, if dependencies are loaded by `Bundler.require`, add the OTLP exporter to the Gemfile:

```ruby
# application dependencies, eg
# gem "rails", "~> 7.0.5", ">= 7.0.5.1"

gem 'opentelemetry-exporter-jaeger'

# end of Gemfile
gem 'solarwinds_apm'
```

And set the environment variable:

```bash
export OTEL_TRACES_EXPORTER=jaeger
```

### Service Name

By default the service name portion of the service key is used, e.g. `my-service` if the service key is `SW_APM_SERVICE_KEY=api-token:my-service`. If the `OTEL_SERVICE_NAME` or `OTEL_RESOURCE_ATTRIBUTES` environment variable is used to specify a service name, it will take precedence over the default.

```bash
# service name for instrumented app will be 'bar', not 'foo'
export SW_APM_SERVICE_KEY=<api-token>:foo
export OTEL_SERVICE_NAME=bar
```

### Instrumentation Libraries

You can use OpenTelemetry Ruby instrumentation environment variables to [disable](https://opentelemetry.io/docs/languages/ruby/libraries/#overriding-configuration-for-specific-instrumentation-libraries-with-environment-variables) or [configure](https://opentelemetry.io/docs/languages/ruby/libraries/#configuring-specific-instrumentation-libraries-with-environment-variables) certain instrumentation, see the [OpenTelemetry Docs](https://opentelemetry.io/docs/languages/ruby/libraries/#use-instrumentation-libraries) for details.

For example, to disable sinatra instrumentation and disable mysql2 instrumentation's obfuscation of db.statement:

```bash
export OTEL_RUBY_INSTRUMENTATION_SINATRA_ENABLED=false
export OTEL_RUBY_INSTRUMENTATION_MYSQL2_CONFIG_OPTS='db_statement=include;'
```

or in your initialization step:

```ruby
ENV['OTEL_RUBY_INSTRUMENTATION_SINATRA_ENABLED'] = 'false'
ENV['OTEL_RUBY_INSTRUMENTATION_MYSQL2_CONFIG_OPTS'] = 'db_statement=include;'
```

## Programmatic Configuration

Many OpenTelemetry instrumentation library configurations can be set within the `SolarWindsAPM::OTelConfig.initialize_with_config ... end` block, please consult the individual [instrumentation](https://github.com/open-telemetry/opentelemetry-ruby-contrib/tree/main/instrumentation) README pages for the options available. Note this takes lower precedence than the [environment varable](#instrumentation-libraries) settings.

> [!IMPORTANT]
> this feature is only enabled if auto-config is disabled via `SW_APM_AUTO_CONFIGURE=false`.

Below is an example that disables Dalli instrumentation and sets the Rack instrumentation to capture certain headers as Span attributes:

```ruby
# note auto-configure must be disabled, e.g.
# export SW_APM_AUTO_CONFIGURE=false

require 'solarwinds_apm'

SolarWindsAPM::OTelNativeConfig.initialize_with_config do |config|
  config["OpenTelemetry::Instrumentation::Dalli"] = {:enabled => false}
  config["OpenTelemetry::Instrumentation::Rack"]  = {:allowed_request_headers => ['header1', 'header2']}
end
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

The configuration file should be Ruby code that sets key/values in the hash exposed by `SolarWindsAPM::Config`. The bundled [Rails generator template file](https://github.com/solarwinds/apm-ruby/blob/main/lib/rails/generators/solarwinds_apm/templates/solarwinds_apm_initializer.rb) serves as an example of the supported values, see also the [Reference](#reference) section.

## Reference

Environment Variable | Config File Key | Description | Default
-------------------- | --------------- | ----------- | -------
`SW_APM_AUTO_CONFIGURE` | N/A  | By default the library is configured to work out-of-the-box with all automatic instrumentation libraries enabled. Set this to `false` to custom initialize the library with configuration options for instrumentation, see [Programmatic Configuration](#programmatic-configuration) for details. | `true`
`SW_APM_COLLECTOR` | N/A | Override the default collector endpoint to which the library connects and exports data. It should be defined using the format host:port. | `apm.collector.na-01.cloud.solarwinds.com:443`
`SW_APM_CONFIG_RUBY` | N/A | Override the default location for the configuration file. This can be an absolute or relative filename, or the directory under which the `solarwinds_apm_config.rb` file would be looked for. | None
`SW_APM_DEBUG_LEVEL` | `:debug_level` | Set the library's logging level, valid values are -1 through 6 (least to most verbose). <br> Setting -1 disables logging from the library. | 3
`SW_APM_ENABLED` | N/A | Enable/disable the library, setting `false` is an alternative to uninstalling `solarwinds_apm` since it will prevent the library from loading. | `true`
`SW_APM_SERVICE_KEY` | `:service_key` | API token and service name in the form of `token:service_name`, **required**. | None
`SW_APM_TAG_SQL` | `:tag_sql` | Enable/disable injecting trace context into supported SQL statements. Set to boolean true or (or string `true` in env var) to enable, see [Tag Query with Trace Context](#tag-query-with-trace-context) for details.| `false`
`SW_APM_TRIGGER_TRACING_MODE` | `:trigger_tracing_mode` | Enable/disable trigger tracing for the service.  Setting to `disabled` may impact DEM visibility into the service. | `enabled`
`SW_APM_LAMBDA_PRELOAD_DEPS` | N/A | This option only takes effect in the AWS Lambda runtime. Set to `false` to disable the attempt to preload function dependencies and install instrumentations. | `true`
`SW_APM_TRANSACTION_NAME` | N/A | Customize the transaction name for all traces, typically used to target specific instrumented lambda functions. _Precedence order_: custom SDK > `SW_APM_TRANSACTION_NAME` > automatic naming | None
N/A | `:log_args` | Enable/disable the collection of URL query parameters, set to boolean false to disable. | true
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

#### Limitation

> [!NOTE]  
> This feature currently does not support prepared statements. For `mysql2` the `query` operation is supported, for `pg` the "[exec-ish](https://github.com/solarwinds/apm-ruby/blob/main/lib/solarwinds_apm/patch/tag_sql/sw_pg_patch.rb#L15)" operations like `exec` and `query` are supported.

### Background Jobs

#### Resque

[Resque](https://github.com/resque/resque) is a Redis-backed library for creating background jobs, queuing them on multiple queues, and processing them later.

When starting the Resque worker, it is necessary to set: `RUN_AT_EXIT_HOOKS=1`.

For example:

```console
RUN_AT_EXIT_HOOKS=1 QUEUE=${QUEUE_NAME} ${EXTRA_OPTIONS} bundle exec rake resque:work
```

Explanation:

* `RUN_AT_EXIT_HOOKS`: This option, provided by Resque, ensures that the forked processes shut down gracefully (i.e., no immediate `exit!`). This allow the background process that handle signal (trace, metrics, etc.) transmission complete their task.

Additionally, you need to configure the Resque initializer in your Rails application by adding the following code to `config/initializers/resque.rb`. It's recommended to have a upper bound time (e.g. 8 seconds) to avoid infinited loop if something wrong with `solarwinds_apm` initialization.
