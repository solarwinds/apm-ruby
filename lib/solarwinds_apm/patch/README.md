## Patch upstream code

This folder is for storing patch files that apply to upstream code.

For example, to patch otel ruby sdk `Registry`, and assume you have dummy_patch file that have module `SolarWindsAPM::Patch::DummyPatch`,

```ruby
require_relative './patch/dummy_patch'

if defined? OpenTelemetry::Instrumentation::Registry && OpenTelemetry::Instrumentation::Registry::VERSION <= '0.3.0'
  OpenTelemetry::Instrumentation::Registry.prepend(SolarWindsAPM::Patch::DummyPatch)
end
```
