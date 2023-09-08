# solarwinds_apm
The `solarwinds_apm` gem starting from version 6.0.0 is an [OpenTelemetry Ruby](https://opentelemetry.io/docs/instrumentation/ruby/) distribution. It provides automatic instrumentation and custom SolarWinds Observability features for Ruby applications.

## Requirements
Only Linux is supported, the gem will go into no-op mode on other platforms. MRI Ruby version 3 or above is required. The [SolarWinds Observability documentation website](https://documentation.solarwinds.com/en/success_center/observability/content/configure/services/ruby/install.htm) has details on the supported platforms and system dependencies.

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to build for development.

## Installation and Setup
`solarwinds_apm` is [available on Rubygems](https://rubygems.org/gems/solarwinds_apm). Install with:
```bash
gem install solarwinds_apm -v '>=6.0.0'
```

Or add to **the end** of your application Gemfile and run `bundle install` if managing gems with Bundler:
```ruby
# application dependencies, eg
# gem "rails", "~> 7.0.5", ">= 7.0.5.1"

# end of Gemfile
gem 'solarwinds_apm', '>=6.0.0'
```

Ideally all application gems are required by `Bundler.require`, which guarantees loading in the order they appear in the Gemfile. If `Bundler.require` does not require all application gems, call `require 'solarwinds_apm'` after all gems that need instrumentation are loaded.

The only required configuration is the service key, which can be set in the `SW_APM_SERVICE_KEY` environment variable or in the configuration file as `:service_key`. See [CONFIGURATION.md](CONFIGURATION.md) for the complete reference.

## Custom Instrumentation

### Create a custom span manually through our helper API

To create a custom span manually as child span (i.e. sub-span) of other parent span or trace.

Here is a simple example with rails controller:

```ruby
require 'solarwinds_apm'

class StaticController < ApplicationController
  def home
    SolarWindsAPM::API.in_span('custom_span') do |span|
      # do things
      object.cool_work()
    end
  end
end
```

This example will start new span called `custom_span` that will be set as the current span in the Tracer‘s context at execution.

SolarWinds Observability APM OpenTelemetry extensions seamlessly integrate with the auto-configured global trace object, eliminating the need to craft your own trace object. However, if you generate and employ a distinct trace object, the manual instrumentation spans won't be identified by the SolarWinds Observability APM extensions nor captured by the SolarWinds APM collector.

### Get current trace and span information

If you want to check current tracestring, trace_id, span_id or trace_flags, you can simply use `current_trace_info` to retrieve the infomation as example shown. The current trace and span information is retreived based on OpenTelemetry Ruby api `::OpenTelemetry::Trace.current_span`

```ruby
trace = SolarWindsAPM::API.current_trace_info

trace.tracestring    # 00-7435a9fe510ae4533414d425dadf4e18-49e60702469db05f-01
trace.trace_id       # 7435a9fe510ae4533414d425dadf4e18
trace.span_id        # 49e60702469db05f
trace.trace_flags    # 01
```

### Check if the solarwinds_apm is ready

The Ruby Library establishes and sustains a link to a SolarWinds Observability collector, retrieving settings essential for tracing decisions. The duration of this initialization can span a few seconds based on the connection quality. If requests come into the application before this setup concludes, they won't be traced. This isn't a significant concern for extended server operations but could pose issues for short-lived applications like cron jobs or CLI apps.

Invoking this method lets the application pause until the library is fully initialized and primed for tracing. An optional timeout parameter, measured in milliseconds, can be provided to specify the maximum wait time for initialization. By default, this is set to 3000 milliseconds. A timeout value of 0 ensures the application doesn't pause at all.

```ruby
require 'solarwinds_apm'

SolarWindsAPM::API.solarwinds_ready(wait_milliseconds=3000)
```

By default, it returns a boolean value of True (ready) or False (not ready).

### Set custom transaction name

The Ruby Library's default instrumentation designates a transaction name derived from detected URL values. If this assigned name doesn't adequately describe your instrumented process, you have the option to replace it with a custom transaction name. For traces with several transaction names, the final name specified is chosen.

```ruby
require 'solarwinds_apm'

result = SolarWindsAPM::API.set_transaction_name('my-custom-trace-name')
```

The function `set_transaction_name` takes a string representing the transaction name for the ongoing request. Both empty strings and null values are not accepted as valid transaction names and will be disregarded. This function yields a boolean result: `True` for successful naming and `False` otherwise.

If a call to `set_transaction_name` is made from an asynchronous execution unit after the service entry span has been processed and sent out, the call will not produce any effect.

### Create a custom span manually using OpenTelemetry Ruby API

To create a custom span without our api function, you need to find the current tracer object from tracer_provider. Tracer object is determined by the service_name. If the SW_APM_SERVICE_KEY is set correctly, then the service name will be the `SW_APM_SERVICE_KEY` after semi-colon (e.g. `<key>:<your_service_name>`). Or you can simply use ENV['OTEL_SERVICE_NAME'] as the example showing

```ruby
current_tracer = ::OpenTelemetry.tracer_provider.tracer(ENV['OTEL_SERVICE_NAME'])
current_tracer.in_span(name, attributes: attributes, links: links, start_timestamp: start_timestamp, kind: kind) do |span|
  # do things
  object.cool_work()
end
```

### Get current span with OpenTelemetry Ruby API

If you wish to add event or exception to current span (e.g. while executing your rails controller), you can find the current span using OpenTelemetry api `::OpenTelemetry::Trace.current_span`, and add information as example shown

```ruby
span = ::OpenTelemetry::Trace.current_span

span.add_event('event', attributes: {'eager' => true})    # add simple 'event' event

span.record_exception(exception, attributes: {})          # exception has to be Ruby Exception/Error object
```

For more OpenTelemetry Ruby API, please view [opentelemetry](https://opentelemetry.io/docs/instrumentation/ruby/manual/)
