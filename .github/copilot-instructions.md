# GitHub Copilot Instructions for solarwinds_apm

## Priority Guidelines

When generating code for this repository:

1. **Version Compatibility**: Always detect and respect the exact versions of Ruby, OpenTelemetry, and dependent gems used in this project
2. **Context Files**: Prioritize patterns and standards defined in the .github/copilot directory when available
3. **Codebase Patterns**: When context files don't provide specific guidance, scan the codebase for established patterns
4. **Architectural Consistency**: Maintain the modular architecture with clear separation between API, config, sampling, and instrumentation layers
5. **Code Quality**: Prioritize maintainability, performance, and security in all generated code

## Technology Version Detection

Before generating code, scan the codebase to identify:

1. **Language Versions**: 
   - Ruby version: **>= 3.1.0** (as specified in solarwinds_apm.gemspec)
   - Never use Ruby features beyond version 3.1 unless the gemspec is updated
   - Always include `# frozen_string_literal: true` as the first line in every Ruby file

2. **Framework Versions**:
   - OpenTelemetry SDK: **>= 1.2.0**
   - OpenTelemetry Instrumentation All: **>= 0.31.0**
   - OpenTelemetry OTLP Exporter: **>= 0.29.1**
   - OpenTelemetry Metrics SDK: **>= 0.2.0**
   - OpenTelemetry Logs SDK: **>= 0.4.0**
   - Respect version constraints when generating code
   - Never suggest OpenTelemetry features not available in the detected versions

3. **Library Versions**:
   - OpenTelemetry Resource Detectors (AWS: **>= 0.1.0**, Azure: **>= 0.2.0**, Container: **>= 0.2.0**)
   - Test framework: Minitest (version **< 5.27.0** for compatibility)
   - Generate code compatible with these specific versions
   - Never use APIs or features not available in the detected versions

## Context Files

Prioritize the following files in .github/copilot directory (if they exist):

- **instructions/*.md**: File-type specific generic instructions for various file types (Ruby, YAML, etc.)
- **architecture.md**: System architecture guidelines
- **tech-stack.md**: Technology versions and framework details
- **coding-standards.md**: Code style and formatting standards
- **folder-structure.md**: Project organization guidelines
- **exemplars.md**: Exemplary code patterns to follow

## Codebase Scanning Instructions

When context files don't provide specific guidance:

1. Identify similar files to the one being modified or created
2. Analyze patterns for:
   - Naming conventions (module names, class names, method names)
   - Code organization (module structure, class hierarchy)
   - Error handling (logging patterns, exception handling)
   - Logging approaches (SolarWindsAPM.logger usage)
   - Documentation style (YARD documentation format)
   - Testing patterns (Minitest describe/it blocks)
   
3. Follow the most consistent patterns found in the codebase
4. When conflicting patterns exist, prioritize patterns in newer files or files with higher test coverage
5. Never introduce patterns not found in the existing codebase

## Architecture and Module Organization

This project follows a layered architecture with clear module boundaries:

### Core Modules

- **SolarWindsAPM**: Root module for the gem
- **SolarWindsAPM::API**: Public API surface exposed to users
  - `TransactionName`: Custom transaction naming
  - `CurrentTraceInfo`: Trace context information
  - `Tracing`: Readiness checks
  - `OpenTelemetry`: OpenTelemetry integration helpers
  - `CustomMetrics`: Custom metrics (deprecated in 7.0.0+)
  - `Tracer`: Custom instrumentation helpers
- **SolarWindsAPM::Config**: Configuration management
- **SolarWindsAPM::OTelConfig**: OpenTelemetry configuration and initialization
- **SolarWindsAPM::Sampling**: Sampling algorithms and trace decisions
  - `OboeSampler`: Main sampling logic with dice roll, parent-based, and trigger trace algorithms
  - `TokenBucket`: Rate limiting for trace sampling
  - `Dice`: Probabilistic sampling decisions
- **SolarWindsAPM::Support**: Utility classes
  - `ServiceKeyChecker`: Service key validation
  - `ResourceDetector`: Resource attribute detection
  - `TransactionSettings`: URL-based sampling configuration
  - `OtlpEndpoint`: OTLP endpoint URL construction
- **SolarWindsAPM::Patch**: Instrumentation patches
  - Tag SQL functionality for MySQL2 and PostgreSQL

### File Organization

- **lib/solarwinds_apm.rb**: Main entry point, handles initialization and configuration
- **lib/solarwinds_apm/**: Module implementations organized by function
- **test/**: Test files mirroring the lib/ structure
- **lib/rails/generators/**: Rails generator templates

## Code Quality Standards

### Maintainability

- Write self-documenting code with clear naming following Ruby conventions
- Use descriptive method names with underscores (e.g., `set_transaction_name`, `should_sample?`)
- Follow the naming pattern: `ModuleName::ClassName.method_name` or `module_name/file_name.rb`
- Keep functions focused on single responsibilities
- Limit method complexity - extract complex logic into private methods
- Use private methods for internal implementation details (e.g., `private_class_method :compile_settings`)
- Organize code with clear module boundaries as seen in existing structure

### Performance

- Use efficient Ruby idioms (e.g., `dig` for nested hash access, `fetch` with defaults)
- Cache expensive computations (see token bucket implementation)
- Use mutexes (`::Mutex`) for thread-safe operations when necessary
- Follow existing patterns for asynchronous operations with OpenTelemetry
- Optimize regex compilation (compile once, use many times)
- Use `freeze` for constants and immutable objects (e.g., `SW_LOG_LEVEL_MAPPING.freeze`)

### Security

- Validate all external inputs (see `TraceOptions.validate_signature` pattern)
- Sanitize SQL queries through parameterization (see tag_sql patch)
- Use environment variables for sensitive configuration (`ENV.fetch` with defaults)
- Follow established authentication patterns for trigger trace validation
- Handle sensitive data (service keys, signatures) according to existing patterns
- Log security-relevant events at appropriate levels

### Error Handling

- Use explicit error handling with rescue blocks
- Log errors with appropriate severity levels using `SolarWindsAPM.logger`
- Provide meaningful error messages with context (module/method name in logs)
- Return status booleans or appropriate values indicating success/failure
- Use `StandardError` as base rescue class unless more specific is needed
- Follow the pattern: catch errors, log them, and handle gracefully (see lib/solarwinds_apm.rb)

## Documentation Requirements

Follow the YARD documentation format found in the codebase:

- Document all public API methods with YARD syntax
- Include `@param` tags for all parameters with type and description
- Include `@return` tags with return type and description
- Document exceptions that may be raised
- Include usage examples in documentation blocks (see API::TransactionName)
- Use inline comments for non-obvious logic, prefixed with `#`
- Document configuration options with their expected types and defaults
- Add copyright headers to all new files following this pattern:

```ruby
# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
```

## Testing Approach

### Unit Testing with Minitest

- Use Minitest's spec-style DSL with `describe` and `it` blocks
- Structure: `describe 'ClassName or feature' do ... end`
- Test naming: `it 'describes_what_the_test_does' do ... end`
- Use `let` blocks for test fixtures and shared setup
- Use `before` and `after` hooks for setup and teardown
- Follow the AAA pattern (Arrange, Act, Assert) within test blocks

### Test Organization

- Mirror the lib/ directory structure in test/
- Group related tests in describe blocks
- Use nested describe blocks for method-specific tests
- Name test files with `_test.rb` suffix (e.g., `config_test.rb`)
- Place integration tests in appropriate subdirectories (e.g., test/patch/)

### Assertions

- Use Minitest expectations: `_(value).must_equal expected`
- Common patterns:
  - `_(result).must_equal expected_value`
  - `_(collection).must_include item`
  - `_(lambda { code }).must_raise ExceptionClass`
  - `_(value).must_be_nil`
  - `_(result).must_be_instance_of ClassName`

### Test Setup

- Use `minitest_helper.rb` for common test configuration
- Set required environment variables in test setup (e.g., `SW_APM_SERVICE_KEY`)
- Use custom test helpers like `CustomInMemorySpanExporter` for OpenTelemetry testing
- Create helper methods for common test operations (e.g., `create_span`, `create_context`)
- Use `skip` directive when tests require specific conditions not met

### Mocking and Stubbing

- Use the mocha gem for mocking (included in test dependencies)
- Follow patterns like `Object.stub(:method, return_value) do ... end`
- Mock external dependencies (HTTP requests, file I/O) in integration tests
- Use `before` blocks to set up mocks and stubs

## OpenTelemetry Integration Patterns

### Span Creation

- Use `::OpenTelemetry.tracer_provider.tracer(name)` to obtain tracers
- Create spans with `tracer.in_span(name, attributes: {...}, kind: :span_kind) do ... end`
- Access current span with `::OpenTelemetry::Trace.current_span`
- Add attributes: `span.add_attributes({key: value})`
- Record exceptions: `span.record_exception(exception)`

### Context Propagation

- Work with context: `::OpenTelemetry::Context.current`
- Set context: `OpenTelemetry::Context.with_current(context) do ... end`
- Extract span context from current span: `span.context`
- Check validity: `span.context.valid?`

### Sampling Decisions

- Return `OTEL_SAMPLING_RESULT.new(decision:, tracestate:, attributes:)`
- Decision types:
  - `OTEL_SAMPLING_DECISION::RECORD_AND_SAMPLE` - trace and export
  - `OTEL_SAMPLING_DECISION::RECORD_ONLY` - trace but don't export
  - `OTEL_SAMPLING_DECISION::DROP` - don't trace
- Manage tracestate: `::OpenTelemetry::Trace::Tracestate.from_hash({...})`

## Configuration Management Patterns

### Environment Variable Handling

- Use `ENV.fetch('VAR_NAME', 'default')` for optional variables
- Use `ENV['VAR_NAME']` for checking presence
- Document all environment variables in CONFIGURATION.md
- Priority: ENV > config file > defaults
- Convert strings to appropriate types (integers, booleans, symbols)

### Config Hash Access

- Access config with symbols: `SolarWindsAPM::Config[:key]`
- Set config: `SolarWindsAPM::Config[:key] = value`
- Validate config values in the setter
- Log warnings for invalid configurations

### Boolean and Symbol Validation

- Use helper methods: `true?`, `boolean?`, `symbol?`
- Convert strings: `'true'.casecmp('true').zero?`
- Validate enabled/disabled: `:enabled` or `:disabled` symbols

## Logging Patterns

### Logger Usage

- Use `SolarWindsAPM.logger` for all logging
- Log levels: `debug`, `info`, `warn`, `error`, `fatal`
- Use blocks for expensive log operations: `SolarWindsAPM.logger.debug { "message" }`
- Include module/method context: `"[#{name}/#{__method__}] message"`
- Use structured logging with variable inspection: `#{variable.inspect}`

### Log Level Mapping

- Respect `SW_APM_DEBUG_LEVEL` environment variable
- Map to both stdlib Logger and OpenTelemetry log levels
- Default log level: INFO (3)
- Level -1: disables logging by setting logger to `Logger.new(nil)`

## Naming Conventions

### Modules and Classes

- Use CamelCase: `SolarWindsAPM`, `OboeSampler`, `TokenBucket`
- Nest modules logically: `SolarWindsAPM::API::TransactionName`
- Use descriptive names that reflect purpose

### Methods

- Use snake_case: `set_transaction_name`, `should_sample?`, `parent_based_algo`
- Use `?` suffix for predicate methods: `ready?`, `boolean?`, `valid?`
- Use `!` suffix for destructive methods or methods with side effects (sparingly)
- Private methods: mark with `private` keyword or `private_class_method :method_name`

### Constants

- Use SCREAMING_SNAKE_CASE: `SAMPLE_RATE_ATTRIBUTE`, `OTEL_SAMPLING_DECISION`
- Freeze constant arrays and hashes: `.freeze`
- Group related constants in modules

### Variables

- Use snake_case: `sample_state`, `trace_flags`, `parent_span`
- Use descriptive names avoiding abbreviations unless conventional
- Instance variables: `@logger`, `@settings`, `@buckets`
- Class variables: `@@config` (use sparingly, prefer class instance variables)

## Versioning and Releases

This project uses Semantic Versioning:

- Version defined in `lib/solarwinds_apm/version.rb`
- Format: `MAJOR.MINOR.PATCH` (with optional PRE for pre-releases)
- MAJOR: Breaking changes
- MINOR: New features, backward compatible
- PATCH: Bug fixes, backward compatible
- Document changes in CHANGELOG.md

## File-Type Specific Instructions

For file-type specific guidance (Ruby files, YAML, Markdown, etc.), refer to the generic instructions in `.github/copilot/instructions/` directory. These provide detailed patterns for:

- Ruby source files (`.rb`)
- Ruby gemspec files (`.gemspec`)
- Test files (`*_test.rb`)
- Configuration files (YAML, JSON)
- Documentation files (Markdown)

**Note**: The `.github/copilot/instructions/` folder should be created using the `/agent-create-or-update-generic-instructions.prompt.md` prompt before using these repository-specific instructions.

## General Best Practices

- Always include `# frozen_string_literal: true` at the top of Ruby files
- Follow Ruby community style guide with project-specific adaptations
- Use meaningful variable names that reflect their purpose
- Keep methods short and focused (aim for < 25 lines)
- Extract complex conditions into well-named private methods
- Use guard clauses to reduce nesting
- Prefer explicit returns for clarity, though implicit returns are acceptable
- Use symbols for hash keys in new code
- Avoid modifying frozen objects
- Thread safety: use mutexes for shared mutable state
- Performance: avoid unnecessary object allocations in hot paths

## Project-Specific Conventions

### Initialization and Lifecycle

- Entry point: `lib/solarwinds_apm.rb`
- Automatic initialization: controlled by `SW_APM_AUTO_CONFIGURE` (default: enabled)
- Manual initialization: `SolarWindsAPM::OTelConfig.initialize` or `initialize_with_config`
- Check if enabled: `ENV.fetch('SW_APM_ENABLED', 'true')`
- Noop mode: require 'solarwinds_apm/noop' when disabled

### Sampling Algorithm Selection

Follow the decision tree (see `OboeSampler#should_sample?`):

1. Local spans: trust parent decision
2. If tracestate present and valid: parent-based algorithm
3. If SAMPLE_START flag set:
   - With X-Trace-Options: trigger trace algorithm
   - Without X-Trace-Options: dice roll algorithm
4. Otherwise: disabled algorithm

### Attribute Naming

Use consistent attribute names:

- `SWKeys`: Custom keys from trigger trace
- `SampleRate`: Sample rate used
- `SampleSource`: Source of sampling decision
- `BucketCapacity`: Token bucket capacity
- `BucketRate`: Token bucket rate
- `TriggeredTrace`: Boolean for triggered traces
- `sw.tracestate_parent_id`: Parent span ID from tracestate

## When in Doubt

- Scan the codebase thoroughly before generating any code
- Respect existing architectural boundaries without exception
- Match the style and patterns of surrounding code
- Prioritize consistency with existing code over external best practices
- If a pattern appears consistently across multiple files, follow it
- If unsure about OpenTelemetry API usage, check existing instrumentation patterns
- Consult README.md and CONFIGURATION.md for user-facing guidance
