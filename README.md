# solarwinds_apm

The `solarwinds_apm` gem starting from version 6.0.0 is an [OpenTelemetry Ruby](https://opentelemetry.io/docs/instrumentation/ruby/) distribution. It provides automatic instrumentation and custom SolarWinds Observability features for Ruby applications.

## Requirements

Only Linux is supported, the gem will go into no-op mode on other platforms. MRI Ruby version 3 or above is required. The [SolarWinds Observability documentation website](https://documentation.solarwinds.com/en/success_center/observability/content/configure/services/ruby/install.htm) has details on the supported platforms and system dependencies.

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to build for development.

## Installation and Setup

`solarwinds_apm` is [available on Rubygems](https://rubygems.org/gems/solarwinds_apm). Install with:

```bash
gem install solarwinds_apm
```

Or add to **the end** of your application Gemfile and run `bundle install` if managing gems with Bundler:

```ruby
# application dependencies, eg
# gem "rails", "~> 7.0.5", ">= 7.0.5.1"

# end of Gemfile
gem 'solarwinds_apm'
```

Ideally all application gems are required by `Bundler.require`, which guarantees loading in the order they appear in the Gemfile. If `Bundler.require` does not require all application gems, call `require 'solarwinds_apm'` after all gems that need instrumentation are loaded.

The only required configuration is the service key, which can be set in the `SW_APM_SERVICE_KEY` environment variable or in the configuration file as `:service_key`. See [CONFIGURATION.md](CONFIGURATION.md) for the complete reference.

## Custom Instrumentation

`solarwinds_apm` supports the standard OpenTelemetry API for tracing and includes a helper to ease its use in manual instrumentation.  Additionally, a set of SolarWindsAPM APIs are provided for features specific to SolarWinds Observability.

### Using the OpenTelemetry API

This gem installs the dependencies needed to use the OTel API and initializes the globally-registered `TracerProvider`. So the "Setup" and "Acquiring a Tracer" sections of the [OTel Ruby Manual Instrumentation](https://opentelemetry.io/docs/instrumentation/ruby/manual/) should be skipped. Instead, your application code should acquire a `Tracer` from the global `TracerProvider` as follows.

The `Tracer` object is determined by the service name, which is the portion after the colon (`:`) set in the `SW_APM_SERVICE_KEY` or `:service_key` configuration. The service name is also automatically set into the `OTEL_SERVICE_NAME` environment variable which can be referenced as shown below. The `Tracer` object can then be used as described in the OTel Ruby documentation.

The example below shows how the standard OTel API to [create a span](https://opentelemetry.io/docs/instrumentation/ruby/manual/#creating-new-spans) and [get the current span](https://opentelemetry.io/docs/instrumentation/ruby/manual/#get-the-current-span) can be used in an application where `solarwinds_apm` has been loaded.  See also the convenience [wrapper for in_span provided by the SolarWindsAPM API](#convenience-method-for-in_span):

```ruby
# acquire the tracer
MyAppTracer = ::OpenTelemetry.tracer_provider.tracer(ENV['OTEL_SERVICE_NAME'])

# create a new span
MyAppTracer.in_span('new.span', attributes: {'key1' => 'value1', 'key2' => 'value2'}) do |span|
  # do things
end

# work with the current span
current_span = ::OpenTelemetry::Trace.current_span
# current_span.add_attributes
# current_span.add_event
# current_span.record_exception
```

Note that if `OpenTelemetry::SDK.configure` is used to set up a `TracerProvider`, it will not be configured with our distribution's customizations and manual instrumentation made with its `Tracer` object will not be reported to SolarWinds Observability.

### Using the SolarWindsAPM API

Several convenience and vendor-specific APIs are availabe to an application where `solarwinds_apm` has been loaded, below is a quick overview of the features provided. The full reference can be found at the [RubyDoc page for this gem](https://rubydoc.info/github/solarwinds/apm-ruby).

#### Convenience Method: `in_span` and `add_tracer`

`in_span` acquires the correct `Tracer` so a new span can be created in a single call.

For example, using it in a Rails controller:

```ruby
class StaticController < ApplicationController
  def home
    SolarWindsAPM::API.in_span('custom_span') do |span|
      # do things
    end
  end
end
```

`add_tracer` can add a custom span to the specified instance or class method that is already defined. It can optionally set the span kind and additional attributes provided in hash format:

```ruby
add_tracer :method_name, 'custom_span_name', { attributes: { 'any' => 'attributes' }, kind: :span_kind }
```

For example, if you want to instrument class or instance method `create_session` inside an application controller:

To instrument instance method
```ruby
class SessionsController < ApplicationController
  include SolarWindsAPM::API::Tracer

  def create
    user = User.find_by(email: params[:session][:email].downcase)
    create_session(user)
  end

  def create_session(user)
  end

  # instrument instance method create_session
  add_tracer :create_session, 'custom_name', { attributes: { 'foo' => 'bar' }, kind: :consumer }
end
```

To instrument class method
```ruby
class SessionsController < ApplicationController
  def create
    user = User.find_by(email: params[:session][:email].downcase)
    create_session(user)
  end

  def self.create_session(user)
  end

  # instrument class method create_session
  class << self
    include SolarWindsAPM::API::Tracer
    add_tracer :create_session, 'custom_name', { attributes: { 'foo' => 'bar' }, kind: :consumer }
  end
end
```

#### Get Curent Trace Context Information

The `current_trace_info` method returns a `TraceInfo` object containing string representations of the current trace context that can be used in logging or manual propagation of context. This is a convenience method that wraps the OTel API `::OpenTelemetry::Trace.current_span`.

```ruby
trace = SolarWindsAPM::API.current_trace_info

trace.tracestring    # 00-7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-01
trace.trace_id       # 7435a9fe510ae4533414d425dadf4e18
trace.span_id        # 49e60702469db05f
trace.trace_flags    # 01
```

#### Check if solarwinds_apm Is Ready

On startup, this library initializes and maintains a connection to a SolarWinds Observability collector, and receives settings used for making tracing decisions. This process can take up to a few seconds depending on the connection. If the application receives requests before initialization has completed, these requests will not be traced. While this is not critical for long-running server processes, it might be a problem for short-running apps such as cron jobs or CLI apps.

A call to the `solarwinds_ready` method allows the application to block until initialization has completed and the library is ready for tracing. The method accepts an optional timeout parameter in milliseconds.

```ruby
SolarWindsAPM::API.solarwinds_ready(wait_milliseconds=3000)
```

#### Set a Custom Transaction Name

By default, transaction names are constructed based on attributes such as the requested route in the server framework, or the span name. If this name is not descriptive enough, you can override it with a custom one. If multiple transaction names are set on the same trace, the last transaction name is used.

```ruby
result = SolarWindsAPM::API.set_transaction_name('my-custom-trace-name')
```

#### Send Custom Metrics

Service metrics are automatically collected by this library.  In addition, the following methods support sending two types of custom metrics:

* `increment_metric` - counts the number of times something has occurred
* `summary_metric` - a specific value for the default count of 1, or the sum of values if count > 1

The metrics submitted are aggregated by metric name and tag(s), then sent every 60 seconds.

```ruby
SolarWindsAPM::API.increment_metric('loop.iteration')
SolarWindsAPM::API.summary_metric('sleep.time', 5000)
```
