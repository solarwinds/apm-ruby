# GitHub Copilot Instructions for solarwinds_apm

## Priority Guidelines

When generating code for this repository:

1. **Version Compatibility**: Always detect and respect the exact versions of Ruby, OpenTelemetry, and dependent gems used in this project
2. **Context Files**: Prioritize patterns and standards defined in the .github/instructions directory when available
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
   - [OpenTelemetry SDK](https://github.com/open-telemetry/opentelemetry-ruby/sdk): **>= 1.2.0**
   - [OpenTelemetry Instrumentation All](https://github.com/open-telemetry/opentelemetry-ruby-contrib/tree/main/instrumentation/all): **>= 0.31.0**
   - [OpenTelemetry OTLP Exporter](https://github.com/open-telemetry/opentelemetry-ruby/tree/main/exporter/otlp): **>= 0.29.1**
   - [OpenTelemetry Metrics OTLP Exporter](https://github.com/open-telemetry/opentelemetry-ruby/tree/main/exporter/otlp-metrics): **>= 0.3.0**
   - [OpenTelemetry Logs OTLP Exporter](https://github.com/open-telemetry/opentelemetry-ruby/tree/main/exporter/otlp-logs): **>= 0.2.1**
   - [OpenTelemetry Metrics SDK](https://github.com/open-telemetry/opentelemetry-ruby/tree/main/metrics_sdk): **>= 0.2.0**
   - [OpenTelemetry Logs SDK](https://github.com/open-telemetry/opentelemetry-ruby/tree/main/logs_sdk): **>= 0.4.0**
   - Respect version constraints when generating code
   - Never suggest OpenTelemetry features not available in the detected versions

3. **Library Versions**:
   - OpenTelemetry Resource Detectors ([AWS](https://github.com/open-telemetry/opentelemetry-ruby-contrib/tree/main/resources/aws): **>= 0.1.0**, [Azure](https://github.com/open-telemetry/opentelemetry-ruby-contrib/tree/main/resources/azure): **>= 0.2.0**, [Container](https://github.com/open-telemetry/opentelemetry-ruby-contrib/tree/main/resources/container): **>= 0.2.0**)
   - Test framework: Minitest (version **< 5.27.0** for compatibility)
   - Generate code compatible with these specific versions
   - Never use APIs or features not available in the detected versions

## Context Files

Prioritize the following files in .github/instructions directory (if they exist):

- **/*.instructions.md**: File-type specific instructions for various file types (Ruby, YAML, etc.)
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

## Ruby Coding Conventions

For comprehensive Ruby coding standards including:

- File headers and frozen string literals
- Module and class organization
- Naming conventions (methods, variables, constants)
- Documentation with YARD
- Error handling and logging patterns
- Environment variable handling
- Testing with Minitest
- OpenTelemetry integration
- Configuration management
- Thread safety and performance optimization

**Refer to [.github/instructions/ruby.instructions.md](.github/instructions/ruby.instructions.md)** which is automatically applied to all Ruby files based on the `applyTo` glob pattern.

## Versioning and Releases

This project uses Semantic Versioning:

- Version defined in `lib/solarwinds_apm/version.rb`
- Format: `MAJOR.MINOR.PATCH` (with optional PRE for pre-releases)
- MAJOR: Breaking changes
- MINOR: New features, backward compatible
- PATCH: Bug fixes, backward compatible
- Document changes in CHANGELOG.md

## File-Type Specific Instructions

For file-type specific guidance (Ruby files, YAML, Markdown, etc.), refer to the instructions in `.github/instructions/` directory. These provide detailed patterns for:

- Ruby source files (`.rb`) - `ruby.instructions.md`
- Ruby gemspec files (`.gemspec`) - `ruby.instructions.md`
- Test files (`*_test.rb`) - `ruby.instructions.md`
- Configuration files (YAML, JSON) - `coding.instructions.md`

**Note**: These instruction files are automatically applied by GitHub Copilot based on the `applyTo` glob patterns specified in their frontmatter.

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
