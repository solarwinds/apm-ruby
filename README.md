# swotel-ruby
An [OpenTelemetry Ruby](https://opentelemetry.io/docs/instrumentation/ruby/) distribution for SolarWinds Observability. Provides automatic configuration, instrumentation, and APM data export for Ruby applications.

----
## Requirements
All published artifacts support Ruby 2.7 or higher. A full list of system requirements is available at [SolarWinds Observability System Requirements](https://documentation.solarwinds.com/en/success_center/observability/content/configure/services/ruby/install.htm).

See [CONTRIBUTING.md](https://github.com/solarwindscloud/swotel-ruby/blob/main/CONTRIBUTING.md) for how to build for development.

## Getting Started

Install by adding `solarwinds_otel_apm` to your Gemfile.

Run your application with require the library and start the initialization.

```ruby
require 'solarwinds_otel_apm'
SolarWindsOTelAPM::OTelConfig.initialize
```

For extra configuration (this will overwrite other configuration)
```ruby
require 'solarwinds_otel_apm'
SolarWindsOTelAPM::OTelConfig.initialize do |config|
  config['key'] = value
end
```

See more information in [in-code-configuration](#configuration-through-in-code-configuration)

e.g. for rails, put it into `config/application.rb`; although you don't need `require 'solarwinds_otel_apm'` if you have `Bundler.require(*Rails.groups)`

## Configuration

swotel-ruby allows several ways of configuration.

The configuration level/priority: in-code configure > environmental variable > config file > default


### Configuration through in-code configuration

Example:

```ruby
require 'solarwinds_otel_apm'

SolarWindsOTelAPM::OTelConfig.initialize do |config|
  config["OpenTelemetry::Instrumentation::Rack"]  = {"a" => "b"}
  config["OpenTelemetry::Instrumentation::Dalli"] = {:enabled: false}
end
```

The above configuration code sets Ruby Rack with configuration as {"a" => "b"}, and sets Ruby Dalli to disabled (not instrumented)

#### Configure propagators in-code
```ruby
require 'opentelemetry/sdk'

trace_context = ::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator.new
baggage       = ::OpenTelemetry::Baggage::Propagation::TextMapPropagator.new,
solarwinds    = SolarWindsOTelAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator.new

SolarWindsOTelAPM::OTelConfig.initialize do |config|
  config["OpenTelemetry::Propagators"] = [trace_context, baggage, solarwinds]
end
```

The above example initialized three different propagators and provide it to `config["OpenTelemetry::Propagators"]` with in-code configuration. This will overwrite the setting from `OTEL_PROPAGATORS`.

#### Configure exporter in-code

```ruby
require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'

exporter = OpenTelemetry::Exporter::OTLP::Exporter.new

SolarWindsOTelAPM::OTelConfig.initialize do |config|
  config["OpenTelemetry::Exporter"] = exporter
end
```

The above example initialized opentelemetry otlp exporter and provide it to `config["OpenTelemetry::Exporter"]` with in-code configuration. This will overwrite the setting from `OTEL_TRACES_EXPORTER`.

#### Configure instrumentation library

By default we try to load all the instrumentation from opentelemetry-ruby-contrib.
However, user can choose disable certain instrumentation if they want.

Example: to disable Dalli, and provide some customization for Rack

Set SWO_OTEL_DEFAULT to false to disable auto-loading of the instrumentation.
```bash
export SWO_OTEL_DEFAULT=false
```

Or set it to false through config file e.g. `SolarWindsOTelAPM::Config[:swo_otel_default] = false` )

When loading the agent,
```ruby
require 'solarwinds_otel_apm'

SolarWindsOTelAPM::OTelConfig.initialize do |config|
  config["OpenTelemetry::Instrumentation::Rack"]  = {"a" => "b"}
  config["OpenTelemetry::Instrumentation::Dalli"] = {:enabled: false}
end
```


### Environmental variable

#### OTEL_TRACES_EXPORTER

Used to define the exporter

Supported exporters: solarwinds

Example:
```bash
export OTEL_TRACES_EXPORTER=solarwinds
```

#### OTEL_PROPAGATORS

Used to define list of propagators

Supported propagators: tracecontext, baggage, solarwinds

```bash
export OTEL_PROPAGATORS=tracecontext,baggage,solarwinds
```

tracecontext and solarwinds are mandatory propagators, and tracecontext has to be in front of solarwinds propagators (e.g. tracecontext,solarwinds)

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

### Configuration files

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
