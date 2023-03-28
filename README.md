# swotel-ruby
OTEL implementation of ruby agent

## Configuration

swotel-ruby allow several way of configuration.

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

The above configuration code set ruby rack with configuration as {"a" => "b"}, and set ruby dalli to disable (not instrumented)

#### Configure propagators in-code
```ruby
require 'opentelemetry/sdk'

propagator = ::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator.new

SolarWindsOTelAPM::OTelConfig.initialize do |config|
  config["OpenTelemetry::Propagators"] = [propagator]
end
```

#### Configure exporter in-code

```ruby
require 'opentelemetry/sdk'

exporter = SolarWindsOTelAPM::OpenTelemetry::SolarWindsExporter.new(txn_manager: txn_manager)

SolarWindsOTelAPM::OTelConfig.initialize do |config|
  config["OpenTelemetry::Exporter"] = exporter
end
```

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

### Configuration files

The configuration file can be in following location

For rails application: config/initializers/solarwinds_otel_apm.rb

For non-rails application: solarwinds_otel_apm_config.rb

Also can be defined with environmental variable `SW_APM_CONFIG_RUBY`

Sample configuration file can be found [here](https://github.com/solarwindscloud/swotel-ruby/blob/main/lib/rails/generators/solarwinds_otel_apm/templates/solarwinds_otel_apm_initializer.rb)


### Default configuration

#### Propagators

Default propagators are tracecontext, baggage, solarwinds

#### Exporter

Default exporter is solarwinds



## Contributing

### Lint

We follow the rubocop rule to lint our ruby code.

To run the rubocop:
```bash
bundle install  # make sure every dependencies are installed
bundle exec rake rubocop
```

The rubocop will produce the file called `rubocop_result.txt`, and you can check the result from it

### Testing

```bash
~# bundle exec rake docker    # initialize the docker containers, and you will enter docker container automatically
root@docker:/code/ruby-solarwinds# test/run_otel_tests/run_tests

# for only running ruby version 2.7.5 test
root@docker:/code/ruby-solarwinds# test/run_otel_tests/run_tests -r 2.7.5
```


#### Run a specific test file, or a specific test
While coding and for debugging it may be helpful to run fewer tests.
To run singe tests the env needs to be set up and use `ruby -I test`

One file:
```bash
rbenv local 2.7.5
export BUNDLE_GEMFILE=gemfiles/delayed_job.gemfile
export DBTYPE=mysql       # optional, defaults to postgresql
bundle
bundle exec rake cfc           # download, compile oboe_api, and link liboboe
bundle exec ruby -I test test/unit/otel_config_test.rb
```

A specific test:
```bash
rbenv global 2.7.5
export BUNDLE_GEMFILE=gemfiles/libraries.gemfile
export DBTYPE=mysql
bundle
bundle exec ruby -I test test/unit/otel_config_test.rb -n /test_resolve_propagators_with_defaults/
```

















## Useful link
https://aws-otel.github.io/docs/getting-started/ruby-sdk/trace-manual-instr