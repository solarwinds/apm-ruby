# Noop Mode

Here we can define modules and classes for noop mode.

Instead of polluting code with SolarWindsAPM.loaded conditionals, we load these classes when in noop mode and they expose noop behavior.

The following methods require noop implementations based on the API modules:

## Currently Implemented Noop Modules in `api.rb`:

- **Tracing**:
  - `solarwinds_ready?(wait_milliseconds=3000, integer_response: false)` - Always returns false

- **CurrentTraceInfo**:
  - `current_trace_info` - Returns a TraceInfo instance with default/empty values
  - TraceInfo class with noop methods: `for_log`, `hash_for_log`, and attributes: `tracestring`, `trace_id`, `span_id`, `trace_flags`, `do_log`

- **CustomMetrics**:
  - `increment_metric(name, count=1, with_hostname=false, tags_kvs={})` - Returns false with deprecation warning
  - `summary_metric(name, value, count=1, with_hostname=false, tags_kvs={})` - Returns false with deprecation warning

- **OpenTelemetry**:
  - `in_span(name, attributes: nil, links: nil, start_timestamp: nil, kind: nil, &block)` - Simply yields to the block if given

- **TransactionName**:
  - `set_transaction_name(custom_name=nil)` - Always returns true

- **CustomInstrumentation/Tracer**:
  - `add_tracer(method_name, span_name=nil, options={})` - Always returns nil.

These modules are extended into `SolarWindsAPM::API` to provide consistent behavior when SolarWindsAPM is disabled or in noop mode.
