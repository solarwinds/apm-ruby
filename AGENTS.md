# Ruby/solarwinds_apm

In the `solarwinds_apm` repository:

- Gem is an OpenTelemetry Ruby distribution (>= 6.0.0).
- MRI Ruby 3.x required. Versions < 7.0.0 are Linux-only (no‑op elsewhere).
- Add `gem 'solarwinds_apm'` at the END of the Gemfile. Do not reorder earlier app dependencies to accommodate it.
- If not using `Bundler.require`, explicitly `require 'solarwinds_apm'` only after all gems needing instrumentation are loaded.
- A service key is REQUIRED: set `SW_APM_SERVICE_KEY=<api_token:service_name>` (or configure `:service_key`). The service name (after the colon) becomes `OTEL_SERVICE_NAME`.
- Do NOT manually call `OpenTelemetry::SDK.configure` to replace the global provider; that breaks distribution customizations.
- The gem auto-initializes TracerProvider + MeterProvider. Replacing globals disables tracing/export.
- Treat startup readiness: short‑lived scripts should call `SolarWindsAPM::API.solarwinds_ready?(wait_ms)` before generating spans.
- Prefer vendor helpers (`SolarWindsAPM::API.in_span`, `add_tracer`) over duplicating tracer acquisition boilerplate.
- Deprecated metric helpers (`increment_metric`, `summary_metric`) are no‑ops >= 7.0.0: use standard OTel Metrics API instead.

## Development Environment

### Setup

1. **Prerequisites**: Install rbenv, Ruby, and bundler (see [rbenv installation guide](https://github.com/rbenv/rbenv#installation))
2. **Clone and setup**:
   ```bash
   git clone <repo-url>
   cd apm-ruby
   rbenv install 3.1.2 && rbenv local 3.1.2
   gem install bundler
   bundle install --path vendor/bundle
   ```
3. **Verify setup**: `bundle exec rake -T` should list available tasks

### Development Workflow

After making changes:

- **Load interactively**: `bundle exec irb -Ilib -r solarwinds_apm` (no build needed)
- **Run single test**: `bundle exec ruby -I test test/opentelemetry/solarwinds_propagator_test.rb`
- **Run test suite**: `APM_RUBY_TEST_KEY=<key> test/run_tests.sh`
- **Lint**: `bundle exec rake rubocop`
- **Full regression**: `bundle exec rake 'docker_tests[,,,APM_RUBY_TEST_KEY=<key>]'`

### Advanced: Container Development (Optional)

For complex debugging: `bundle exec rake docker_dev` provides isolated environment with all tools.

## Linting & Formatting

- Run `bundle exec rake rubocop` before committing; fix issues recorded in `rubocop_result.txt`.
- Do not silence cops without justification; prefer code changes over blanket disables.
- Keep public API docs accurate when changing method signatures (update YARD/RubyDoc comments if present).

## Manual Instrumentation Conventions

- Acquire tracers via: `Tracer = OpenTelemetry.tracer_provider.tracer(ENV['OTEL_SERVICE_NAME'])`; do not hardcode service names.
- Use `SolarWindsAPM::API.in_span('logical.operation', attributes: {...})` for convenience.
- Method instrumentation:
  ```
  include SolarWindsAPM::API::Tracer
  add_tracer :method_name, 'span.name', { attributes: { 'key' => 'value' }, kind: :consumer }
  ```
- Keep span names concise, lowercase with dots (`component.action`).
- Prefer attribute keys matching semantic conventions where applicable.
- Use `SolarWindsAPM::API.current_trace_info` for logging correlation IDs (avoid reimplementing W3C header parsing).
- Only set a custom transaction name when the framework default is ambiguous; last assignment wins.

## Metrics Conventions

- Create instruments through the global meter:
  ```
  Meter = OpenTelemetry.meter_provider.meter('solarwinds_apm.custom')
  counter = Meter.create_counter('operation.count', description: 'Count of X', unit: '{operation}')
  counter.add(1, attributes: { 'foo' => 'bar' })
  ```
- Choose units and names consistent with OTel semantic conventions; use `{unit}` braces for ad‑hoc units.

## Readiness & Startup

- For batch/CLI tasks:
  ```
  SolarWindsAPM::API.solarwinds_ready?(2000) || warn('Tracing not initialized in time')
  ```
- Avoid long blocking waits in web servers; readiness is mainly for short processes.

## Tests

**Interactive loading**: `bundle exec irb -Ilib -r solarwinds_apm`

**Single test**:
```
bundle exec ruby -I test test/opentelemetry/solarwinds_propagator_test.rb
bundle exec ruby -I test test/opentelemetry/solarwinds_propagator_test.rb -n /trace_state_header/
```

**Local suite**: `APM_RUBY_TEST_KEY=<key> test/run_tests.sh`

**Full regression**:
```
bundle exec rake 'docker_tests[,,,APM_RUBY_TEST_KEY=<key>]'
bundle exec rake 'docker_tests[3.2-alpine,,linux/amd64,APM_RUBY_TEST_KEY=<key>]'
```

**Setup only**: `test/test_setup.sh`

Logs: Check `log/` directory for test output and debugging.

### Test Change Scope Guidelines

- Pure doc / comment changes: no test run required (optional quick lint).
- Instrumentation logic, exporter, propagator, or API changes: run baseline suite + at least one additional Ruby version.
- Dependency version matrix adjustments: run all configured Ruby variants.
- Failing tests before commit are not acceptable; do not mark flakey without issue reference.

## Release / Build Checklist (Internal)

1. **Code quality**: `bundle exec rake rubocop` passes
2. **Tests**: Suite green on primary supported Ruby versions
3. **Build**: `bundle exec rake build_gem` → verify `gem spec builds/solarwinds_apm-*.gem name version`
4. **Smoke test**: `SW_APM_SERVICE_KEY=<key> bundle exec irb -Ilib -r solarwinds_apm` (spans export, no warnings)

## Common Pitfalls

- Reinitializing OpenTelemetry -> lose customized processors/exporters.
- Forgetting to append gem at end of Gemfile -> instrumentation may miss early‑loaded libraries.
- Attempting to use deprecated custom metric helpers on >= 7.0.0 -> they are intentional no‑ops.
- Not waiting in short‑lived scripts -> zero spans exported.

## Quick API Reference

| Task | Call |
|------|------|
| Create span | `SolarWindsAPM::API.in_span('name') { ... }` |
| Instrument method | `add_tracer :m, 'span.m'` |
| Current trace info | `SolarWindsAPM::API.current_trace_info` |
| Ready check | `SolarWindsAPM::API.solarwinds_ready?(1500)` |
| Custom transaction name | `SolarWindsAPM::API.set_transaction_name('custom')` |
| Counter metric | `meter.create_counter('metric').add(1, attributes: {...})` |

## Logging Correlation

Use `trace = SolarWindsAPM::API.current_trace_info` then include `trace.trace_id` and `trace.span_id` in structured logs; do not attempt to read internal span context fields directly.

## Performance Notes

- Keep attribute key/value counts minimal in high-frequency spans.
- Avoid excessive synchronous metric instrument creation; cache instruments globally.
- Prefer method instrumentation (`add_tracer`) over wrapping public call sites repeatedly.

## Do Not

- Do not rename public module namespaces (`SolarWindsAPM::API`).
- Do not vendor or fork OpenTelemetry SDK inside this repo.
- Do not add hidden global state affecting sampler/exporter without documentation.
- Do not bypass provided readiness API with ad‑hoc sleep loops.

## When in Doubt

- Follow existing file-local style.
- Mirror OTel semantic conventions.
- Keep spans short-lived and purposeful.
