# SolarWinds APM Ruby Configuration Guide

This guide covers all configuration options for the SolarWinds APM Ruby gem, an OpenTelemetry-based distribution that provides automatic instrumentation and observability features for Ruby applications.

## Quick Start

To get started quickly, you only need to set your service key:

```bash
export SW_APM_SERVICE_KEY=<your-api-token>:<your-service-name>
```

By default, all applicable instrumentations are enabled and the gem works out-of-the-box with sensible defaults.

### Minimal Example

```ruby
# Set the service key (required)
ENV['SW_APM_SERVICE_KEY'] = 'your-api-token:my-ruby-app'

# Require the gem (typically done automatically by Bundler)
require 'solarwinds_apm'

# Your application code here
```

## Configuration Precedence

Configuration can be set in multiple ways with the following precedence order (highest to lowest):

1. **Environment Variables** - Highest priority
2. **Programmatic Configuration** - Set in Ruby code
3. **Configuration Files** - Rails initializer or config file
4. **Default Values** - Built-in defaults

## Environment Variables

Environment variables are the most flexible way to configure the SolarWinds APM gem, especially in containerized or cloud environments. All SolarWinds APM-specific settings are prefixed with `SW_APM_`. Standard [OpenTelemetry environment variables](https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/) are also supported where applicable.

**Required Configuration**

| Variable | Description | Example |
|----------|-------------|---------|
| `SW_APM_SERVICE_KEY` | API token and service name (required) | `your-token:my-service` |

**Common Configuration**

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `SW_APM_ENABLED` | Enable/disable the entire library | `true` | `false` |
| `SW_APM_DEBUG_LEVEL` | Logging verbosity (-1 to 6) | `3` | `5` |
| `SW_APM_COLLECTOR` | Collector endpoint override | `apm.collector.na-01.cloud.solarwinds.com:443` | `apm.collector.eu-01.cloud.solarwinds.com:443` |

For more configuration options see [Configuration Reference](#configuration-reference).

### OpenTelemetry Integration

#### Exporters

This gem uses the OTLP exporter by default. You can configure additional exporters for debugging or multi-backend scenarios:

```bash
export OTEL_TRACES_EXPORTER=console          # Console Exporter (for debugging)
export OTEL_TRACES_EXPORTER=otlp,console     # Multiple Exporters
export OTEL_TRACES_EXPORTER=jaeger           # Third-party Exporters (e.g. jaeger, add gem opentelemetry-exporter-jaeger before solarwinds_apm)
```

The API token from `SW_APM_SERVICE_KEY` is automatically added as an `authorization` header only for a SolarWinds Observability OTLP endpoint (`https://otel.collector.*.*.solarwinds.com`) and when neither the general OTLP headers variable nor that signal's headers variable has a non-empty value. It is automatically added to the signal-specific variable (e.g. `OTEL_EXPORTER_OTLP_TRACES_HEADERS`), never to `OTEL_EXPORTER_OTLP_HEADERS`.

To route telemetry from an OTel Collector in your environment to SolarWinds Observability, please configure the API token in your OTelCol's exporter.

#### Service Name

By default the service name portion of the service key is used, e.g. `my-service` if the service key is `SW_APM_SERVICE_KEY=api-token:my-service`. If the `OTEL_SERVICE_NAME` or `OTEL_RESOURCE_ATTRIBUTES` environment variable is used to specify a service name, it will take precedence over the default. The precedence is as follows:

`OTEL_SERVICE_NAME` > `OTEL_RESOURCE_ATTRIBUTES` > `SW_APM_SERVICE_KEY` > `SolarWindsAPM::Config[:service_key]`

Service key format:

```bash
export SW_APM_SERVICE_KEY=<api-token>:<service-name>
```

Override with OpenTelemetry variables:

```bash
# Service name will be 'production-api', not 'my-service'
export SW_APM_SERVICE_KEY=<api-token>:my-service
export OTEL_SERVICE_NAME=production-api
```

Resource attributes:

```bash
export OTEL_RESOURCE_ATTRIBUTES=service.name=production-api,service.version=1.2.3
```

#### Instrumentation Control

Fine-tune individual instrumentation libraries using OpenTelemetry environment variables:

Disable specific instrumentation:

```bash
export OTEL_RUBY_INSTRUMENTATION_SINATRA_ENABLED=false
export OTEL_RUBY_INSTRUMENTATION_REDIS_ENABLED=false
```

Configure instrumentation options:

```bash
# Include full SQL statements (disable obfuscation)
export OTEL_RUBY_INSTRUMENTATION_MYSQL2_CONFIG_OPTS='db_statement=include;'

# Configure HTTP instrumentation
export OTEL_RUBY_INSTRUMENTATION_NET_HTTP_CONFIG_OPTS='untraced_hosts=localhost,internal.service;'
```

Set inside file through ENV hash:

```ruby
# Set before requiring solarwinds_apm
ENV['OTEL_RUBY_INSTRUMENTATION_MYSQL2_CONFIG_OPTS'] = 'db_statement=include;'
ENV['OTEL_RUBY_INSTRUMENTATION_NET_HTTP_CONFIG_OPTS'] = 'untraced_hosts=localhost,internal.service;'
```

See the [OpenTelemetry Ruby instrumentation documentation](https://opentelemetry.io/docs/languages/ruby/libraries/) for all available options.

#### Exporting Application Logs

The [Logger instrumentation](https://github.com/open-telemetry/opentelemetry-ruby-contrib/tree/main/instrumentation/logger) is a log appender for the Ruby `logger` that bridges messages into OTel log record format for export. By default this instrumentation is disabled; it can be enabled by setting the environment variable `OTEL_RUBY_INSTRUMENTATION_LOGGER_ENABLED=true`.

## Programmatic Configuration

For advanced use cases, you can configure OpenTelemetry instrumentation libraries programmatically using the `SolarWindsAPM::OTelConfig.initialize_with_config` block.

### Prerequisites

> **⚠️ Important:** Programmatic configuration requires disabling auto-configuration:

```bash
export SW_APM_AUTO_CONFIGURE=false
```

### Basic Example

Below is an example that disables Dalli instrumentation and sets the Rack instrumentation to capture certain headers as Span attributes:

```ruby
# note auto-configure must be disabled, e.g. export SW_APM_AUTO_CONFIGURE=false
require 'solarwinds_apm'
SolarWindsAPM::OTelConfig.initialize_with_config do |config|
  config["OpenTelemetry::Instrumentation::Dalli"] = {:enabled => false}
  config["OpenTelemetry::Instrumentation::Rack"]  = {:allowed_request_headers => ['header1', 'header2']}
end
```

Advanced Configuration

```ruby
SolarWindsAPM::OTelConfig.initialize_with_config do |config|
  # HTTP client configuration
  config["OpenTelemetry::Instrumentation::Net::HTTP"] = {
    untraced_hosts: ['localhost', 'internal.service.com'],
    untraced_requests: ->(uri, req) { uri.path == '/health' }
  }

  # Rails configuration
  config["OpenTelemetry::Instrumentation::Rails"] = {
    enable_recognize_route: true,
    enable_dependency_tracking: true
  }

  # Redis configuration
  config["OpenTelemetry::Instrumentation::Redis"] = {
    peer_service: 'redis-cluster',
    db_statement_serializer: ->(stmt) { stmt.truncate(100) }
  }
end
```

> **Reference:** Consult individual [instrumentation README files](https://github.com/open-telemetry/opentelemetry-ruby-contrib/tree/main/instrumentation) for complete configuration options.

## Configuration Files

The configuration file should be Ruby code that sets key/values in the hash exposed by `SolarWindsAPM::Config`. The bundled [Rails generator template file](https://github.com/solarwinds/apm-ruby/blob/main/lib/rails/generators/solarwinds_apm/templates/solarwinds_apm_initializer.rb) serves as an example of the supported values, see also the [Configuration Reference](#configuration-reference) section.

### How to install the file

#### Rails Applications

For Rails applications, use the built-in generator to create a configuration file:

```bash
bundle exec rails generate solarwinds_apm:install
```

This creates `config/initializers/solarwinds_apm.rb` with documented configuration options.

#### Non-Rails Applications

Create the configuration file anywhere (for example `/etc/solarwinds_apm/config.rb`) and set `SW_APM_CONFIG_RUBY` to its **absolute** path:

```ruby
# /etc/solarwinds_apm/config.rb
SolarWindsAPM::Config[:service_key] = 'your-token:your-service'
SolarWindsAPM::Config[:debug_level] = 3
SolarWindsAPM::Config[:tag_sql] = true
```

```bash
export SW_APM_CONFIG_RUBY=/etc/solarwinds_apm/config.rb
```

Configuration files are not auto-discovered for non-Rails applications. A `solarwinds_apm_config.rb` in the current working directory isn't loaded; the agent logs a warning instead.

#### Custom Location

Rails applications can also use a different file by setting `SW_APM_CONFIG_RUBY` to its absolute path:

```bash
export SW_APM_CONFIG_RUBY=/path/to/your/config.rb
```

### Config File Selection

At most one configuration file is loaded:

1. If `SW_APM_CONFIG_RUBY` is set, only that file is used. It must be an absolute path to a file. A relative path, a directory, or a missing file means no configuration file is loaded, and the agent doesn't fall back to the Rails initializer.
2. Otherwise, for Rails applications only, the agent loads `config/initializers/solarwinds_apm.rb` from the Rails application root. The root is `Rails.root` when it's available, or the directory of the absolute `BUNDLE_GEMFILE` set by the Rails `config/boot.rb`. The current working directory is never searched.

### Config File Security

Config files are executed as Ruby code with the application's privileges. On POSIX systems (Linux, macOS), the agent resolves symlinks in the path set by `SW_APM_CONFIG_RUBY`, then refuses to load the file, and logs a warning, if:

- the file is world-writable,
- the file isn't owned by `root` or by the effective user running the application,
- any directory in the resolved path, up to `/`, isn't owned by `root` or by the effective user, or
- any directory in the resolved path is world-writable without the sticky bit.

Secure the file's and its directories' ownership and permissions (e.g. owned by the application user with file permission `600`) so the file is loaded. The agent loads the resolved file, so a symlink can't be retargeted between the check and the load.

For example, if the application runs as the user `app`, make the file owned by that user and readable only by it:

```bash
sudo chown app /etc/solarwinds_apm/config.rb
sudo chmod 600 /etc/solarwinds_apm/config.rb
```

Or keep the file owned by `root` and let the application read it:

```bash
sudo chown root:root /etc/solarwinds_apm/config.rb
sudo chmod 644 /etc/solarwinds_apm/config.rb
```

A `root`-owned file with permission `600` passes the checks, but only an application running as `root` can read it.

Standard locations such as `/etc` or the application user's home directory already meet the directory requirements. Common reasons a file is rejected:

- The file is owned by another user, such as a deploy or CI user. Change its owner to the application user or `root`.
- The file is under a world-writable directory without the sticky bit, such as a shared mount with permission `777`. Move the file or fix that directory's permissions.

For Docker and Kubernetes, see [Containers (Docker and Kubernetes)](#containers-docker-and-kubernetes).

The warning names the file or directory that failed the check and the reason.

These checks don't apply to the Rails initializer `config/initializers/solarwinds_apm.rb`, because Rails loads every file in `config/initializers` regardless. Protect it like the rest of your application code.

> **Note:** On non-POSIX systems (Windows), file permission bits aren't meaningful, so the agent skips these checks. Secure the configuration file with Windows ACLs instead.

### Containers (Docker and Kubernetes)

Rails applications that use `config/initializers/solarwinds_apm.rb` without setting `SW_APM_CONFIG_RUBY` aren't affected by the [Config File Security](#config-file-security) checks. When `SW_APM_CONFIG_RUBY` is set in a container, the checks use the user the container runs as, which is often different from the user that owns the application files. The simplest setup that works for any container user is a file owned by `root` with permission `644`, in a directory owned by `root` that isn't world-writable, such as `/etc/solarwinds_apm`.

#### Docker

`COPY` creates files owned by `root` unless `--chown` is given, so copy the file outside the application directory and set its permission:

```dockerfile
COPY solarwinds_apm_config.rb /etc/solarwinds_apm/config.rb
RUN chmod 644 /etc/solarwinds_apm/config.rb
ENV SW_APM_CONFIG_RUBY=/etc/solarwinds_apm/config.rb
```

The file is rejected in these common cases:

- The file is copied with `COPY --chown=<app user>` (or sits in an application directory owned by that user), but the container runs as a different user: as `root` because the image has no `USER` instruction, through `docker run --user`, or with an arbitrary user ID assigned by the platform (e.g. OpenShift). Keep the file owned by `root`, or run the container as the user that owns it.
- The file is bind-mounted (`docker run -v`, Compose `volumes`) from a Linux host, where it keeps the host user's ID. It's trusted only if that ID is `0` or matches the container user. Docker Desktop on macOS presents bind-mounted files as owned by the container user.
- The file or one of its directories was made world-writable, for example with `chmod -R 777` to work around permission errors.

#### Kubernetes

How the file is mounted determines whether it passes the checks:

| Volume type | Result | Reason |
|---|---|---|
| `configMap` mounted as a directory | Rejected | The kubelet creates the mount directory with permission `777` and no sticky bit, even though the volume is mounted read-only. |
| `configMap` mounted with `subPath` | Trusted | The file is mounted directly into a directory owned by `root`. |
| `secret` or `projected` | Trusted | The mount directory is a `tmpfs` with permission `1777` (sticky bit set). |
| `emptyDir` (e.g. populated by an init container) | Rejected | The directory has permission `777` and no sticky bit. |

The file must also be owned by `root` or by the container user. ConfigMap, Secret and projected files are owned by `root`, so `runAsUser` and `fsGroup` don't affect them. Don't set `defaultMode` to a world-writable mode such as `0666` or `0777`.

For example, mount a ConfigMap key with `subPath`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
    - name: app
      image: my-app:latest
      env:
        - name: SW_APM_CONFIG_RUBY
          value: /etc/solarwinds_apm/config.rb
      volumeMounts:
        - name: solarwinds-apm-config
          mountPath: /etc/solarwinds_apm/config.rb
          subPath: config.rb
  volumes:
    - name: solarwinds-apm-config
      configMap:
        name: solarwinds-apm-config
```

Files mounted with `subPath` don't receive ConfigMap updates. This doesn't matter here, because the configuration file is only read when the application starts.

Or mount a Secret as a directory:

```yaml
      volumeMounts:
        - name: solarwinds-apm-config
          mountPath: /etc/solarwinds_apm
          readOnly: true
  volumes:
    - name: solarwinds-apm-config
      secret:
        secretName: solarwinds-apm-config
```

## Configuration Topics

### Transaction Filtering

Specific transactions can be disabled from tracing (suppressing both spans and metrics) using the `:transaction_settings` configuration. An example that filters out static assets, health check requests, and a background job consumer:

```ruby
SolarWindsAPM::Config[:transaction_settings] = [
  {
    regexp: '\.(css|js|png|jpg|gif|ico|woff2?)$',
    opts: Regexp::IGNORECASE,
    tracing: :disabled
  },
  {
    regexp: '/health|/status|/ping',
    tracing: :disabled
  },
  {
    regexp: 'CONSUMER:.*process',  # Background job patterns
    tracing: :disabled
  }
]
```

### SQL Query Tagging

Append trace context to database queries as SQL comments for correlation between traces and database logs.

```bash
export SW_APM_TAG_SQL=true        # Enable SQL tagging
```

Output:

```sql
-- Before (without tagging)
SELECT * FROM users WHERE id = 1;

-- After (with tagging)
SELECT * FROM users WHERE id = 1; /* traceparent=7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-01 */
```

Supported Operations:

- **MySQL2**: `query` operations
- **PostgreSQL**: the "[exec-ish](https://github.com/solarwinds/apm-ruby/blob/main/lib/solarwinds_apm/patch/tag_sql/sw_pg_patch.rb#L15)" operations like `exec` and `query` are supported.

> **⚠️ Limitation:** Currently does not support prepared statements.

### Log Trace Context Integration

Include trace context in your application logs for better correlation:

```ruby
SolarWindsAPM::Config[:log_traceId] = :traced
```

This adds trace and span IDs to log entries when using supported logging frameworks. See also [Exporting Application Logs](#exporting-application-logs) on how to send logs to SolarWinds Observability.

### Background Job Configuration: Resque

When starting the Resque worker, it is necessary to set `RUN_AT_EXIT_HOOKS=1`. For example:

```bash
RUN_AT_EXIT_HOOKS=1 QUEUE=myqueue bundle exec rake resque:work
```

The `RUN_AT_EXIT_HOOKS=1` ensures background processes complete before worker shutdown. This allows the background processes that handle signal (trace, metrics, etc.) transmission to complete their tasks.

### Proxy Configuration

Starting with version 7.0.0, the environment variable `SW_APM_PROXY` and configuration file option `:http_proxy` are deprecated since telemetry is exported with standard OTLP exporters. These exporters use Ruby
's `Net::HTTP`, which supports configuring an [HTTP proxy](https://docs.ruby-lang.org/en/master/Net/HTTP.html#class-Net::HTTPSession-label-Proxy+Server). The examples below set the `http_proxy` environment variable for the Ruby process to configure the proxy:

```bash
# proxy server with no authentication
http_proxy=http://<proxyHost>:<proxyPort> ruby my.app

# proxy server that requires basic authentication
http_proxy=http://<username>:<password>@<proxyHost>:<proxyPort> ruby my.app
```

> **Note:** Starting with version 7.0.0, `SW_APM_PROXY` is deprecated in favor of standard HTTP proxy environment variables.

### Lambda Configuration

For AWS Lambda deployments:

```bash
# Disable dependency preloading if needed
export SW_APM_LAMBDA_PRELOAD_DEPS=false

# Set custom transaction names
export SW_APM_TRANSACTION_NAME=my-lambda-function
```

## Configuration Reference

| Environment Variable | Config File Key | Description | Default |
| -------------------- | --------------- | ----------- | ------- |
| `SW_APM_AUTO_CONFIGURE` | N/A  | By default the library is configured to work out-of-the-box with all automatic instrumentation libraries enabled. Set this to `false` to custom initialize the library with configuration options for instrumentation, see [Programmatic Configuration](#programmatic-configuration) for details. | `true` |
| `SW_APM_COLLECTOR` | N/A | Override the default collector endpoint to which the library connects and exports data. It should be defined using the format host:port. | `apm.collector.na-01.cloud.solarwinds.com:443` |
| `SW_APM_CONFIG_RUBY` | N/A | Absolute path of the configuration file. Required to load a configuration file in non-Rails applications. Relative paths and directories are rejected. When set, the Rails initializer location is not searched. | None |
| `SW_APM_DEBUG_LEVEL` | `:debug_level` | Set the library's logging level, valid values are -1 through 6 (least to most verbose). <br> Setting -1 disables logging from the library. | 3 |
| `SW_APM_ENABLED` | N/A | Enable/disable the library, setting `false` is an alternative to uninstalling `solarwinds_apm` since it will prevent the library from loading. | `true` |
| `SW_APM_SERVICE_KEY` | `:service_key` | API token and service name in the form of `token:service_name`, **required**. | None |
| `SW_APM_TAG_SQL` | `:tag_sql` | Enable/disable injecting trace context into supported SQL statements. Set to boolean true or (or string `true` in env var) to enable, see [Tag Query with Trace Context](#sql-query-tagging) for details.| `false` |
| `SW_APM_TRIGGER_TRACING_MODE` | `:trigger_tracing_mode` | Enable/disable trigger tracing for the service.  Setting to `disabled` may impact DEM visibility into the service. | `enabled` |
| `SW_APM_LAMBDA_PRELOAD_DEPS` | N/A | This option only takes effect in the AWS Lambda runtime. Set to `false` to disable the attempt to preload function dependencies and install instrumentations. | `true` |
| `SW_APM_TRANSACTION_NAME` | N/A | Customize the transaction name for all traces, typically used to target specific instrumented lambda functions. _Precedence order_: custom SDK > `SW_APM_TRANSACTION_NAME` > automatic naming | None |
| N/A | `:log_traceId` | Configure the insertion of trace context into application logs, setting `:traced` would include the available context fields such as trace_id, span_id into log messages. | `:never` |
| N/A | `:tracing_mode` | Enable/disable the tracing mode for this service, setting `:disabled` would suppress all trace spans and metrics. | `:enabled` |
| N/A | `:transaction_settings` | Configure tracing mode per transaction, aka transaction filtering. See [Transaction Filtering](#transaction-filtering) for details.| None |

### Debug Levels

| Level | Description |
|-------|-------------|
| `-1` | Logging disabled |
| `0` | Fatal errors only |
| `1` | Errors |
| `2` | Warnings |
| `3` | Info (default) |
| `4` | Debug |
| `5` | Verbose |
| `6` | Maximum verbosity |

## Troubleshooting

### Log Analysis

Enable debug logging and look for:

- Service key validation
- Collector connection status
- Instrumentation loading
- Span creation and export

```bash
# Enable detailed logging
export SW_APM_DEBUG_LEVEL=5
# Or use otel debug level
export OTEL_LOG_LEVEL=debug
```

For additional help, see the [SolarWinds documentation](https://documentation.solarwinds.com/en/success_center/observability/content/configure/services/ruby/install.htm) or contact support.
