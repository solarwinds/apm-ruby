# AGENTS.md

## Project Overview

The `solarwinds_apm` gem is an OpenTelemetry Ruby distribution that provides automatic instrumentation and observability features for Ruby applications. It's built on top of OpenTelemetry SDK >= 1.2.0 and supports Ruby >= 3.1.0.

**Key Technologies:**

- Ruby >= 3.1.0
- [OpenTelemetry SDK](https://github.com/open-telemetry/opentelemetry-ruby/tree/main/sdk): **>= 1.2.0**
- [OpenTelemetry Instrumentation All](https://github.com/open-telemetry/opentelemetry-ruby-contrib/tree/main/instrumentation/all): **>= 0.31.0**
- [OpenTelemetry OTLP Exporter](https://github.com/open-telemetry/opentelemetry-ruby/tree/main/exporter/otlp): **>= 0.29.1**
- [OpenTelemetry Metrics OTLP Exporter](https://github.com/open-telemetry/opentelemetry-ruby/tree/main/exporter/otlp-metrics): **>= 0.3.0**
- [OpenTelemetry Logs OTLP Exporter](https://github.com/open-telemetry/opentelemetry-ruby/tree/main/exporter/otlp-logs): **>= 0.2.1**
- [OpenTelemetry Metrics SDK](https://github.com/open-telemetry/opentelemetry-ruby/tree/main/metrics_sdk): **>= 0.2.0**
- [OpenTelemetry Logs SDK](https://github.com/open-telemetry/opentelemetry-ruby/tree/main/logs_sdk): **>= 0.4.0**
- Minitest for testing
- RuboCop for code quality

**Architecture:**

- Modular design with clear separation: API, Config, Sampling, Support, Patch
- Entry point: `lib/solarwinds_apm.rb`
- Test suite mirrors lib/ structure

## Setup Commands

For detailed setup instructions, see [CONTRIBUTING.md](CONTRIBUTING.md#development-environment-setup).

## Development Workflow

For complete development workflow, see [CONTRIBUTING.md](CONTRIBUTING.md#development-workflow).

### File Organization

- **Source code**: `lib/`
  - `solarwinds_apm.rb` - Main entry point
  - `solarwinds_apm/` - Core implementation
    - `api/` - Public API methods (TransactionName, CurrentTraceInfo, Tracing, OpenTelemetry)
    - `api.rb` - API module loader
    - `config.rb` - Configuration management
    - `otel_config.rb` - OpenTelemetry configuration and initialization
    - `sampling/` - Sampling algorithms (OboeSampler, TokenBucket, Dice, TraceOptions)
    - `sampling.rb` - Sampling module loader
    - `support/` - Utility classes (ServiceKeyChecker, ResourceDetector, TransactionSettings, OtlpEndpoint)
    - `support.rb` - Support module loader
    - `patch/` - Instrumentation patches (MySQL2, PostgreSQL SQL tagging)
    - `opentelemetry/` - OpenTelemetry extensions (propagator, processor)
    - `noop/` - No-op implementations when disabled
    - `version.rb` - Gem version
    - `constants.rb` - Shared constants
    - `logger.rb` - Logger configuration
  - `rails/generators/` - Rails generator templates
- **Tests**: `test/` (mirrors lib/ structure)
  - `minitest_helper.rb` - Test setup and helpers
  - `run_tests.sh` - Test execution script
  - `api/` - API tests (custom instrumentation, transaction naming, tracing readiness)
  - `sampling/` - Sampling tests (dice, sampler, token bucket, trace options)
  - `opentelemetry/` - OpenTelemetry tests (propagator, processor)
  - `support/` - Support tests (service key checker, resource detector, OTLP endpoint)
  - `patch/` - Patch tests (MySQL2, PostgreSQL)
  - `solarwinds_apm/` - Core functionality tests
- **Configuration**:
  - `solarwinds_apm.gemspec` - Gem specification
  - `Gemfile` - Development dependencies
  - `Rakefile` - Build and test tasks
  - `.rubocop.yml` - RuboCop configuration
- **Documentation**:
  - `README.md` - User-facing documentation
  - `CONTRIBUTING.md` - Contribution guidelines
  - `CONFIGURATION.md` - Configuration reference
  - `CHANGELOG.md` - Version history
  - `AGENTS.md` - This file (AI agent instructions)
  - `SECURITY.md` - Security policy
- **Build artifacts**:
  - `builds/` - Built gem files
  - `doc/` - Generated YARD documentation
  - `coverage/` - Test coverage reports
  - `log/` - Test execution logs

## Testing Instructions

For comprehensive testing instructions, see [CONTRIBUTING.md](CONTRIBUTING.md#testing-your-changes).

### Test File Patterns

- All test files end with `_test.rb`
- Use Minitest spec-style DSL: `describe` and `it` blocks
- Test structure: `describe 'ClassName' do ... end`
- Assertions: Use `assert`, `refute`, `_(value).must_equal expected`

## Code Style

### Ruby Conventions

- **Always** start files with `# frozen_string_literal: true`
- Include copyright header after frozen string literal
- Use snake_case for methods: `set_transaction_name`, `should_sample?`
- Use `?` suffix for predicate methods: `ready?`, `valid?`
- Use CamelCase for modules/classes: `SolarWindsAPM`, `OboeSampler`
- Use SCREAMING_SNAKE_CASE for constants: `SAMPLE_RATE_ATTRIBUTE`
- Freeze constant collections: `.freeze`

### Module Organization

- Use proper nesting: `SolarWindsAPM::API::TransactionName`
- File names match class names in snake_case
- Place classes in: `lib/solarwinds_apm/module_name/class_name.rb`

### Logging Patterns

Always use `SolarWindsAPM.logger` with context:

```ruby
SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] message" }
SolarWindsAPM.logger.warn { "[#{self.class}/#{__method__}] warning: #{details}" }
```

Use block syntax for expensive operations to avoid evaluation when not needed.

### Error Handling

```ruby
begin
  # code
rescue StandardError => e
  SolarWindsAPM.logger.error { "[#{self.class}/#{__method__}] Error: #{e.message}" }
  false # return status boolean
end
```

### Linting

See [CONTRIBUTING.md](CONTRIBUTING.md#code-quality) for details.

**All linting issues must be resolved before submitting PR.**

## Build and Deployment

### Build Gem Locally

For local testing:

```bash
bundle exec rake build_gem
```

Output: `builds/solarwinds_apm-X.Y.Z.gem`

The script shows SHA256 checksum and lists the last 5 built gems.

### Build for GitHub Packages

```bash
bundle exec rake build_gem_for_github_package[7.1.0]
```

### Push to GitHub Packages

Requires credentials in `~/.gem/credentials`:

```bash
bundle exec rake push_gem_to_github_package[7.1.0]
```

### Build and Publish to RubyGems

**For maintainers only:**

```bash
bundle exec rake build_and_publish_gem
```

Requires `GEM_HOST_API_KEY` environment variable and gem >= 3.0.5.

## Pull Request Guidelines

For complete PR guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md).

**Before submitting:**

1. Run all checks: `bundle exec rake rubocop && test/run_tests.sh`
2. All RuboCop issues resolved
3. All tests passing
4. Add tests for changes

**PR titles:** Use descriptive titles that explain the change (e.g., `Fix sampling decision for parent-based traces`)

## Additional Context

### Version Compatibility

- **Ruby**: >= 3.1.0 (specified in gemspec)
- **OpenTelemetry SDK**: >= 1.2.0
- Never use features from newer versions without updating requirements

### Documentation Standards

- Public API methods must have YARD documentation
- Include `@param`, `@return`, and usage examples
- Document configuration options in CONFIGURATION.md
- Update README.md for user-facing changes

### OpenTelemetry Integration Patterns

Access current span:

```ruby
current_span = ::OpenTelemetry::Trace.current_span
```

Create spans:

```ruby
tracer.in_span('span_name', attributes: {...}, kind: :span_kind) do |span|
  # your code
end
```

Work with context:

```ruby
::OpenTelemetry::Context.with_current(context) do
  # code with context
end
```

### Configuration Access

```ruby
# Read config
value = SolarWindsAPM::Config[:key]

# Set config
SolarWindsAPM::Config[:key] = value

# Environment variables take precedence
ENV['SW_APM_ENABLED'] || SolarWindsAPM::Config[:enabled]
```

### Thread Safety

Use mutexes for shared mutable state:

```ruby
@mutex = ::Mutex.new
@mutex.synchronize do
  @shared_state = new_value
end
```

### Debugging Tips

- Use `bundle exec irb -Ilib -r solarwinds_apm` for quick testing
- Check `log/testrun_*.log` for test execution details
- Set `SW_APM_DEBUG_LEVEL=5` for verbose logging
- Use Docker containers to test against specific Ruby versions
- Run single test files to isolate issues

### Common Gotchas

- Tests require `SW_APM_SERVICE_KEY` environment variable
- Some integration tests need actual service keys (contact maintainers)
- Alpine containers may have different behavior than Debian-based
- Always run RuboCop before committing
- Test logs accumulate in `log/` directory

### File Locations

- Main entry: `lib/solarwinds_apm.rb`
- Configuration: `lib/solarwinds_apm/config.rb`
- Version: `lib/solarwinds_apm/version.rb`
- Gemspec: `solarwinds_apm.gemspec`
- Test helper: `test/minitest_helper.rb`
- CI workflows: `.github/workflows/`

### Related Documentation

- [README.md](README.md) - User-facing documentation
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- [CONFIGURATION.md](CONFIGURATION.md) - Configuration reference
- [CHANGELOG.md](CHANGELOG.md) - Version history
