# swotel-ruby
An [OpenTelemetry Ruby](https://opentelemetry.io/docs/instrumentation/ruby/) distribution for SolarWinds Observability. Provides automatic configuration, instrumentation, and APM data export for Ruby applications.

----
## Requirements
All published artifacts support Ruby 2.7 or higher. A full list of system requirements is available at [SolarWinds Observability System Requirements](https://documentation.solarwinds.com/en/success_center/observability/content/configure/services/ruby/install.htm).

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to build for development.

## Getting Started

The `solarwinds_otel_apm` gem is hosted on RubyGems. To install, run `gem install solarwinds_otel_apm` or add `gem 'solarwinds_otel_apm'` at the end of your Gemfile if the application manages gems using Bundler.

Ideally all application gems are required by `Bundler.require`, which guarantees loading in the order they appear in the Gemfile. If `Bundler.require` does not require all application gems, call `require 'solarwinds_otel_apm'` after all gems that need instrumentation are loaded.

Set the service key and ingestion endpoint. An easy way to do this is via environment variables available to your application process. An example:

```bash
export SW_APM_SERVICE_KEY=<set-service-key-here>
export SW_APM_COLLECTOR=<set-collector-here>
```

## Configuration

`solarwinds_otel_apm` is configured to work out-of-the-box for SolarWinds Observability with all automatic instrumentation libraries enabled. The service key is the only required configuration; all other configurations are optional.

Options to control the Ruby Library behavior can be set several ways, with the following precedence:

`in-code configure > environmental variable > config file > default`

### In-code Configuration

Additional configuration can be set within the `SolarWindsOTelAPM::OTelConfig.initialize` block, this will overwrite the same options set via environment variable or configuration file.

An example that disables the Dalli instrumentation and sets the Rack instrumentation to capture certain headers as Span attributes.
```ruby
require 'solarwinds_otel_apm'

SolarWindsOTelAPM::OTelConfig.initialize do |config|
  config["OpenTelemetry::Instrumentation::Dalli"] = {:enabled: false}
  config["OpenTelemetry::Instrumentation::Rack"]  = {:allowed_request_headers: ['header1', 'header2']}
end
```

### Environmental Variable

More environmental variable can be found in [CONFIG.md](https://github.com/solarwindscloud/swotel-ruby/blob/main/CONFIG.md)

#### OTEL_TRACES_EXPORTER

Used to define the exporter

Supported exporters: solarwinds

Example:
```bash
export OTEL_TRACES_EXPORTER=otlp
```

#### OTEL_PROPAGATORS

Used to define list of propagators

Supported propagators can be found [here](https://github.com/open-telemetry/opentelemetry-ruby/blob/main/sdk/lib/opentelemetry/sdk/configurator.rb#L199-L208)

```bash
export OTEL_PROPAGATORS=tracecontext,baggage
```

#### OTEL_SERVICE_NAME

```bash
export OTEL_SERVICE_NAME=your_service_name
```

#### SW_APM_CONFIG_RUBY

```bash
export SW_APM_CONFIG_RUBY=config/file/location.rb
```

#### SW_APM_SERVICE_KEY

```bash
export SW_APM_SERVICE_KEY=<key>:<service_name>
```


### Configuration Files

The configuration file can be in one of the following locations

For rails application: config/initializers/solarwinds_otel_apm.rb

For non-rails application: solarwinds_otel_apm_config.rb

Sample configuration file can be found [here](https://github.com/solarwindscloud/swotel-ruby/blob/main/lib/rails/generators/solarwinds_otel_apm/templates/solarwinds_otel_apm_initializer.rb)


Also can be defined with environmental variable `SW_APM_CONFIG_RUBY`

```bash
export SW_APM_CONFIG_RUBY=config/file/location.rb
```

### Default configuration

#### Propagators

Default propagators are tracecontext, baggage, solarwinds

#### Exporter

Default exporter is solarwinds
