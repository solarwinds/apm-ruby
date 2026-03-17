# solarwinds_apm Examples

Quick-start examples demonstrating tracing, metrics, logs, and custom instrumentation with the `solarwinds_apm` gem.

> **⚠️ Warning: Gem Installation**
> Each example uses `bundler/inline`, which will **automatically download and install `solarwinds_apm` and all its OpenTelemetry dependencies** (`opentelemetry-ruby`, `opentelemetry-ruby-contrib`, etc.) into your system Ruby gem directory on the first run.
> If you do not want to modify your local gem environment, run the examples inside an isolated environment such as a Docker container or a dedicated rbenv/rvm gemset.

## Prerequisites

- **Ruby >= 3.1.0**
- **Bundler** (`gem install bundler`)
- **SolarWinds Observability service key** — obtain one from [SolarWinds Observability](https://support.solarwinds.com/observability)

Set the required environment variable before running any example:

```bash
export SW_APM_SERVICE_KEY=<your-api-token>:<your-service-name>
```

The format is `token:service_name` where `service_name` is how your application appears in SolarWinds Observability.

## Examples

| File | Description |
|------|-------------|
| [traces_example.rb](traces_example.rb) | Create custom trace spans using both the SolarWindsAPM convenience API and the standard OpenTelemetry API. Demonstrates nested spans, trace context, and custom transaction names. |
| [metrics_example.rb](metrics_example.rb) | Record custom metrics (counters, up-down counters, histograms) using the OpenTelemetry Metrics API with the MeterProvider configured by `solarwinds_apm`. |
| [logs_example.rb](logs_example.rb) | Emit structured log records using the OpenTelemetry Logs API, correlated with the current trace context. |
| [custom_instrumentation_example.rb](custom_instrumentation_example.rb) | Use `add_tracer` to automatically wrap existing instance and class methods with trace spans — no manual span creation needed. |

## Running the Examples

Each example is self-contained and uses `bundler/inline` to resolve dependencies, so no separate `bundle install` is needed.

### Traces

```bash
ruby traces_example.rb
```

### Metrics

The export interval is set to 2 seconds (`OTEL_METRIC_EXPORT_INTERVAL=2000`) so results appear quickly. The default is 60 seconds.

```bash
OTEL_METRIC_EXPORT_INTERVAL=2000 OTEL_METRICS_EXPORTER=otlp ruby metrics_example.rb
```

### Logs

```bash
OTEL_RUBY_INSTRUMENTATION_LOGGER_ENABLED=true ruby logs_example.rb
```

### Custom Instrumentation

```bash
ruby custom_instrumentation_example.rb
```

## Console Output for Development

To see exported data printed to the console (useful during local development), use the `console` exporter for the relevant signal:

```bash
# Traces
OTEL_TRACES_EXPORTER=console ruby traces_example.rb

# Metrics
OTEL_METRICS_EXPORTER=console OTEL_METRIC_EXPORT_INTERVAL=2000 ruby metrics_example.rb

# Logs
OTEL_LOGS_EXPORTER=console OTEL_RUBY_INSTRUMENTATION_LOGGER_ENABLED=true ruby logs_example.rb

# Custom Instrumentation
OTEL_TRACES_EXPORTER=console ruby custom_instrumentation_example.rb
```

## Configuration

See [CONFIGURATION.md](../CONFIGURATION.md) for the full configuration reference, including:

- Debug logging (`SW_APM_DEBUG_LEVEL`)
- Collector endpoint override (`SW_APM_COLLECTOR`)
- Transaction filtering
- SQL query tagging
- Programmatic instrumentation configuration

## Validating Results in SolarWinds Observability

After running an example, sign in to [SolarWinds Observability](https://my.na-01.cloud.solarwinds.com/) and navigate as follows:

### Verify Traces and Custom Instrumentation

**APM → \<your-service-name\> → Traces**

Spans created by `traces_example.rb` and `custom_instrumentation_example.rb` appear here within a few seconds of the script completing.

### Verify Logs

**Logs → search** `program:"<your-service-name>"`

Log records emitted by `logs_example.rb` appear here.

### Verify Metrics

**APM → \<your-service-name\> → Metrics**

Metrics recorded by `metrics_example.rb` (e.g. `app.requests`, `app.active_connections`, `app.request.duration`) appear here. Set `OTEL_METRIC_EXPORT_INTERVAL=2000` to reduce the wait to ~2 seconds instead of the default 60.

## Additional Resources

- [SolarWinds APM Ruby README](../README.md)
- [OpenTelemetry Ruby Documentation](https://opentelemetry.io/docs/instrumentation/ruby/)
- [SolarWinds Observability Documentation](https://documentation.solarwinds.com/en/success_center/observability/default.htm)
