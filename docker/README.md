# autoinstrumentation-ruby image

This directory holds the files for the SolarWinds APM `autoinstrumentation-ruby` image used with the OpenTelemetry Operator:

- [Dockerfile](./Dockerfile) builds the image.
- [Gemfile](./Gemfile) lists the gems installed into the image.
- [autoinstrumentation.rb](./autoinstrumentation.rb) is the entry point. The application loads it through `RUBYOPT`, for example `RUBYOPT="-r /otel-auto-instrumentation-ruby/src/autoinstrumentation"`.

## Comparison with the upstream OpenTelemetry entry point

[autoinstrumentation.rb](./autoinstrumentation.rb) is based on the upstream [opentelemetry-auto-instrumentation.rb](https://github.com/open-telemetry/opentelemetry-ruby-instrumentation/blob/main/lib/opentelemetry-auto-instrumentation.rb). Both use the same bootstrap pattern. The upstream file configures the OpenTelemetry SDK itself, while this file leaves that to `require 'solarwinds_apm'`.

### What's the same

- **Gem path and `$LOAD_PATH`:** both read `OTEL_RUBY_ADDITIONAL_GEM_PATH` (default `/otel-auto-instrumentation-ruby`, falling back to `Gem.dir`). Both put the image's gems at the front of `$LOAD_PATH`.
- **Extra gems:** both use the same allowlist (`google-protobuf`, `googleapis-common-protos-types`), which can be trimmed with `DISALLOWED_LIB_PATH`.
- **Bundler hook:** both prepend a patch to `Bundler::Runtime#require` and use a mutex to run setup only once.
- **Gemfile warning:** both warn if the app's Gemfile already lists the gems the image provides.
- **Environment variables:** both honor `OTEL_RUBY_REQUIRE_BUNDLER` and `OTEL_RUBY_AUTO_INSTRUMENTATION_DEBUG`.

### Differences

| Area | Upstream (`opentelemetry-auto-instrumentation.rb`) | SolarWinds (`autoinstrumentation.rb`) |
|---|---|---|
| **Gems added to `$LOAD_PATH`** | `opentelemetry-*` | `opentelemetry-*` and `solarwinds_apm-*` |
| **Gems loaded at startup** | Loads the SDK, metrics/logs SDKs, the three OTLP exporters and `opentelemetry-instrumentation-all` before Bundler runs. | Loads no OpenTelemetry gems itself. `solarwinds_apm` loads what it needs. |
| **SDK setup after `Bundler.require`** | Calls `OpenTelemetry::SDK.configure` itself. | Just runs `require 'solarwinds_apm'`, which sets up the SDK on load (`c.use_all(@@config_map)` in [otel_config.rb](../lib/solarwinds_apm/otel_config.rb)). This adds the SolarWinds sampler, propagators, processors and config. |
| **Choosing instrumentations** | Supports `OTEL_RUBY_ENABLED_INSTRUMENTATIONS`. Names are matched against the instrumentation registry, with snake_case aliases. Uses `c.use` for each listed one, or `c.use_all` if none are listed. | Doesn't support `OTEL_RUBY_ENABLED_INSTRUMENTATIONS`. Always `use_all`, adjusted by `solarwinds_apm`'s own config and the per-instrumentation `OTEL_RUBY_INSTRUMENTATION_*` variables. |
| **Resource detectors** | Turned on by `OTEL_RUBY_RESOURCE_DETECTORS` (`container`, `azure`, `aws`), which loads and merges the matching detectors. | Handled inside `solarwinds_apm` by [resource_detector.rb](../lib/solarwinds_apm/support/resource_detector.rb) (AWS EC2, Azure, Container). `OTEL_RUBY_RESOURCE_DETECTORS` is ignored. |
| **Distro resource** | Adds `telemetry.distro.name` = `opentelemetry-ruby-instrumentation` plus its version. | Not set here; resource attributes come from `solarwinds_apm`. |
| **Value returned by the patched `require`** | Returns the result of its setup step, not what Bundler returned (`super` is called but its result is dropped). | Returns Bundler's result. |
| **When setup fails** | Catches `StandardError`, clears the "initialized" flag, and tries again on the next `require`. | Catches `StandardError` and `LoadError`, but doesn't retry: the flag stays set, so a failure is final. |
| **Gemfile check** | Looks for `opentelemetry-*` gems. | Looks for `opentelemetry-*` and `solarwinds_apm`. |
| **Log prefix** | `[OpenTelemetry]` | `[solarwinds_apm]` |
| **Version** | Loads `opentelemetry/auto_instrumentation/version`. | No version file. |

### What this means in practice

- **Configuration:** with this image, set things through `SW_APM_*` and `solarwinds_apm`'s configuration (see [CONFIGURATION.md](../CONFIGURATION.md)). The upstream-only variables `OTEL_RUBY_ENABLED_INSTRUMENTATIONS` and `OTEL_RUBY_RESOURCE_DETECTORS` do nothing.
- **Failed setup:** if `require 'solarwinds_apm'` fails once, this file won't try again. Upstream retries on every later `Bundler.require`. This is a deliberate choice: it prevents repeated warnings, but there is no recovery.
- **Upstream's patched `require`:** it returns the setup result instead of Bundler's result. Bundler usually ignores that value, so it rarely matters. This file preserves Bundler's result.
