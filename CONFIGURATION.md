# SolarWinds APM Ruby Configuration Guide

This guide covers all configuration options for the SolarWinds APM Ruby gem, an OpenTelemetry-based distribution that provides automatic instrumentation and observability features for Ruby applications.

## Table of Contents

- [Quick Start](#quick-start)
- [Configuration Precedence](#configuration-precedence)
- [Environment Variables](#environment-variables)
- [Configuration Files](#configuration-files)
- [Programmatic Configuration](#programmatic-configuration)
- [Advanced Configuration](#advanced-configuration)
- [Configuration Reference](#configuration-reference)
- [Troubleshooting](#troubleshooting)

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

> **💡 Tip:** Environment variables always take precedence, making them ideal for deployment-specific settings.

## Environment Variables

Environment variables are the most flexible way to configure the SolarWinds APM gem, especially in containerized or cloud environments.

### Core Settings

All SolarWinds APM-specific settings are prefixed with `SW_APM_`. Standard OpenTelemetry environment variables are also supported where applicable.

#### Required Configuration

| Variable | Description | Example |
|----------|-------------|---------|
| `SW_APM_SERVICE_KEY` | API token and service name (required) | `your-token:my-service` |

#### Common Configuration

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `SW_APM_ENABLED` | Enable/disable the entire library | `true` | `false` |
| `SW_APM_DEBUG_LEVEL` | Logging verbosity (-1 to 6) | `3` | `5` |
| `SW_APM_COLLECTOR` | Collector endpoint override | `apm.collector.na-01.cloud.solarwinds.com:443` | `custom.collector.com:443` |

### OpenTelemetry Integration

#### Exporters

The SolarWinds backend uses the OTLP exporter by default. You can configure additional exporters for debugging or multi-backend scenarios:

**Console Exporter (for debugging):**
```bash
export OTEL_TRACES_EXPORTER=console
```

**Multiple Exporters:**
```bash
export OTEL_TRACES_EXPORTER=otlp,console
```

**Third-party Exporters:**

For exporters like Jaeger, first add them to your Gemfile:

```ruby
# Add before solarwinds_apm in your Gemfile
gem 'opentelemetry-exporter-jaeger'
gem 'solarwinds_apm'
```

Then configure:
```bash
export OTEL_TRACES_EXPORTER=jaeger
```

#### Service Naming

The service name is extracted from your service key by default, but can be overridden:

**Service key format:**
```bash
export SW_APM_SERVICE_KEY=<api-token>:<service-name>
```

**Override with OpenTelemetry variables:**
```bash
# Service name will be 'production-api', not 'my-service'
export SW_APM_SERVICE_KEY=<api-token>:my-service
export OTEL_SERVICE_NAME=production-api
```

**Resource attributes:**
```bash
export OTEL_RESOURCE_ATTRIBUTES=service.name=production-api,service.version=1.2.3
```

#### Instrumentation Control

Fine-tune individual instrumentation libraries using OpenTelemetry environment variables:

**Disable specific instrumentation:**
```bash
export OTEL_RUBY_INSTRUMENTATION_SINATRA_ENABLED=false
export OTEL_RUBY_INSTRUMENTATION_REDIS_ENABLED=false
```

**Configure instrumentation options:**
```bash
# Include full SQL statements (disable obfuscation)
export OTEL_RUBY_INSTRUMENTATION_MYSQL2_CONFIG_OPTS='db_statement=include;'

# Configure HTTP instrumentation
export OTEL_RUBY_INSTRUMENTATION_NET_HTTP_CONFIG_OPTS='untraced_hosts=localhost,internal.service;'
```

Set inside file through ENV hash
```ruby
# Set before requiring solarwinds_apm
ENV['OTEL_RUBY_INSTRUMENTATION_SINATRA_ENABLED'] = 'false'
ENV['OTEL_RUBY_INSTRUMENTATION_MYSQL2_CONFIG_OPTS'] = 'db_statement=include;'
```

> **📚 Learn More:** See the [OpenTelemetry Ruby instrumentation documentation](https://opentelemetry.io/docs/languages/ruby/libraries/) for all available options.

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
# note auto-configure must be disabled, e.g.
# export SW_APM_AUTO_CONFIGURE=false

require 'solarwinds_apm'

SolarWindsAPM::OTelConfig.initialize_with_config do |config|
  config["OpenTelemetry::Instrumentation::Dalli"] = {:enabled => false}
  config["OpenTelemetry::Instrumentation::Rack"]  = {:allowed_request_headers => ['header1', 'header2']}
end
```

### Advanced Configuration

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

> **📖 Reference:** Consult individual [instrumentation README files](https://github.com/open-telemetry/opentelemetry-ruby-contrib/tree/main/instrumentation) for complete configuration options.

## Configuration Files

Configuration files provide a centralized way to manage settings, especially useful for complex configurations or when using multiple environments.

### Rails Applications

For Rails applications, use the built-in generator to create a configuration file:

```bash
bundle exec rails generate solarwinds_apm:install
```

This creates `config/initializers/solarwinds_apm.rb` with documented configuration options.

### Non-Rails Applications

Create a file named `solarwinds_apm_config.rb` in your application's root directory:

```ruby
# solarwinds_apm_config.rb
SolarWindsAPM::Config[:service_key] = 'your-token:your-service'
SolarWindsAPM::Config[:debug_level] = 3
SolarWindsAPM::Config[:tag_sql] = true
```

### Custom Location

Override the default configuration file location:

```bash
export SW_APM_CONFIG_RUBY=/path/to/your/config.rb
```

### Configuration File Template

Here's a comprehensive configuration file example:

```ruby
# SolarWinds APM Configuration

# Required: Service key
SolarWindsAPM::Config[:service_key] = ENV['SW_APM_SERVICE_KEY']

# Logging and debugging
SolarWindsAPM::Config[:debug_level] = 3
SolarWindsAPM::Config[:log_traceId] = :traced

# Tracing configuration
SolarWindsAPM::Config[:tracing_mode] = :enabled
SolarWindsAPM::Config[:trigger_tracing_mode] = :enabled

# Database query tagging
SolarWindsAPM::Config[:tag_sql] = false

# Transaction filtering (see Advanced Configuration section)
SolarWindsAPM::Config[:transaction_settings] = [
  {
    regexp: '\.(css|js|png|jpg|gif|ico)$',
    opts: Regexp::IGNORECASE,
    tracing: :disabled
  }
]
```

## Advanced Configuration

### Transaction Filtering

Control which transactions are traced using pattern-based filtering. This is useful for excluding static assets, health checks, or other requests that don't need tracing.

**Configuration:**
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

**Pattern Matching:**
- Uses Ruby regular expressions
- Matches against the transaction name
- Supports regex options like `Regexp::IGNORECASE`
- Can disable both spans and metrics

### SQL Query Tagging

Append trace context to database queries as SQL comments for correlation between traces and database logs.

**Enable SQL tagging:**
```bash
export SW_APM_TAG_SQL=true
```

**Example output:**
```sql
-- Before (without tagging)
SELECT * FROM users WHERE id = 1;

-- After (with tagging)
SELECT * FROM users WHERE id = 1; 
/* traceparent=7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-01 */
```

**Supported Operations:**
- **MySQL2**: `query` operations
- **PostgreSQL**: `exec`, `query`, and similar operations

> **⚠️ Limitation:** Currently does not support prepared statements.

### Log Trace Context Integration

Include trace context in your application logs for better correlation:

```ruby
SolarWindsAPM::Config[:log_traceId] = :traced
```

This adds trace and span IDs to log entries when using supported logging frameworks.

### Background Job Configuration

#### Resque

When using Resque, ensure graceful shutdown for proper trace transmission:

```bash
RUN_AT_EXIT_HOOKS=1 QUEUE=myqueue bundle exec rake resque:work
```

The `RUN_AT_EXIT_HOOKS=1` ensures background processes complete before worker shutdown. This allows the background processes that handle signal (trace, metrics, etc.) transmission to complete their tasks.

### Proxy Configuration

Starting with version 7.0.0, the environment variable `SW_APM_PROXY` and configuration file option `:http_proxy` are deprecated since telemetry is exported with standard OTLP exporters. These exporters use Ruby's `Net::HTTP`, which supports configuring an [HTTP proxy](https://docs.ruby-lang.org/en/master/Net/HTTP.html#class-Net::HTTPSession-label-Proxy+Server). The examples below set the `http_proxy` environment variable for the Ruby process to configure the proxy:

For environments requiring HTTP proxies, configure using standard Ruby `Net::HTTP` proxy environment variables:

**Basic proxy:**
```bash
# proxy server with no authentication
http_proxy=http://<proxyHost>:<proxyPort> ruby my.app

# proxy server that requires basic authentication
http_proxy=http://<username>:<password>@<proxyHost>:<proxyPort> ruby my.app
```

> **📝 Note:** Starting with version 7.0.0, `SW_APM_PROXY` is deprecated in favor of standard HTTP proxy environment variables.

### Lambda Configuration

For AWS Lambda deployments:

```bash
# Disable dependency preloading if needed
export SW_APM_LAMBDA_PRELOAD_DEPS=false

# Set custom transaction names
export SW_APM_TRANSACTION_NAME=my-lambda-function
```

## Configuration Reference

### Environment Variables

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
N/A | `:log_traceId` | Configure the insertion of trace context into application logs, setting `:traced` would include the available context fields such as trace_id, span_id into log messages. | `:never`
N/A | `:tracing_mode` | Enable/disable the tracing mode for this service, setting `:disabled` would suppress all trace spans and metrics. | `:enabled`
N/A | `:transaction_settings` | Configure tracing mode per transaction, aka transaction filtering. See [Transaction Filtering](#transaction-filtering) for details.| None

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