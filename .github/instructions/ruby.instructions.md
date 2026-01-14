---
applyTo: "**/*.rb,**/*.gemspec,**/Gemfile,**/Rakefile"
description: 'Ruby coding conventions and best practices for the solarwinds_apm gem'
---

# Ruby Coding Instructions

## File Header and Frozen String Literal

- **Always** include `# frozen_string_literal: true` as the **first line** of every Ruby file
- Add the copyright header after the frozen string literal:

```ruby
# frozen_string_literal: true

# © 2026 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
```

## Module and Class Organization

- Use proper module nesting with `::` notation: `SolarWindsAPM::API::TransactionName`
- Organize related functionality into modules (e.g., `SolarWindsAPM::API`, `SolarWindsAPM::Config`, `SolarWindsAPM::Sampling`)
- Place classes in appropriately named files matching the class name in snake_case
- Use `self.included(base)` pattern for module inclusion with class methods:

```ruby
module SolarWindsAPM
  module API
    module Tracer
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        # class methods here
      end
    end
  end
end
```

## Naming Conventions

### Methods
- Use snake_case for method names: `set_transaction_name`, `should_sample?`, `parent_based_algo`
- Use `?` suffix for predicate methods that return boolean: `ready?`, `valid?`, `running?`, `boolean?`
- Use `!` suffix sparingly for destructive methods or methods with side effects
- Use `=` suffix for setter methods: `capacity=`, `tokens=`

### Variables
- Use snake_case: `sample_state`, `trace_flags`, `parent_span`, `service_name`
- Use descriptive names that convey purpose
- Instance variables: `@logger`, `@settings`, `@buckets`, `@timer`
- Class variables: `@@config` (use sparingly, prefer class instance variables)

### Constants
- Use SCREAMING_SNAKE_CASE: `SAMPLE_RATE_ATTRIBUTE`, `OTEL_SAMPLING_DECISION`
- Freeze constant collections: `SW_LOG_LEVEL_MAPPING.freeze`, `EXEC_ISH_METHODS.freeze`
- Group related constants at the top of the class or module

### Modules and Classes
- Use CamelCase: `SolarWindsAPM`, `OboeSampler`, `TokenBucket`, `ServiceKeyChecker`
- Use descriptive names that reflect purpose and responsibility

## Attribute Accessors

- Use `attr_reader` for read-only attributes: `attr_reader :token, :service_name`
- Use `attr_accessor` for read-write attributes: `attr_accessor :logger`
- Use `attr_writer` for write-only attributes (rare)
- Define custom setters when validation or side effects are needed:

```ruby
def capacity=(capacity)
  @capacity = [0, capacity].max
end

def tokens=(tokens)
  @tokens = tokens.clamp(0, @capacity)
end
```

## Method Visibility

- Mark private methods with `private` keyword
- Use `private_class_method :method_name` for private class methods
- Place `private` keyword before the private methods section
- Public methods should come before private methods

## Documentation with YARD

- Document all public API methods with YARD syntax
- Use `#` for instance methods and `.` for class methods in documentation
- Include `@param` tags with types and descriptions
- Include `@return` tags with return types
- Add usage examples in documentation blocks

Example:
```ruby
# Provide a custom transaction name
#
# === Argument:
#
# * +custom_name+ - A non-empty string with the custom transaction name
#
# === Example:
#
#   SolarWindsAPM::API.set_transaction_name(custom_name)
#
# === Returns:
# * Boolean
#
def set_transaction_name(custom_name = nil)
  # implementation
end
```

## Error Handling

- Use explicit `rescue` blocks with specific exception types
- Log errors with appropriate severity using `SolarWindsAPM.logger`
- Include module/class and method context in log messages: `"[#{self.class}/#{__method__}] message"`
- Return status booleans or appropriate values indicating success/failure
- Use `StandardError` as base rescue class unless more specific is needed:

```ruby
begin
  # code
rescue StandardError => e
  SolarWindsAPM.logger.error { "[#{self.class}/#{__method__}] Error: #{e.message}" }
end
```

## Logging Patterns

- Always use `SolarWindsAPM.logger` for all logging
- Use block syntax for expensive operations: `SolarWindsAPM.logger.debug { "message" }`
- Include context in log messages: `"[#{self.class}/#{__method__}] message"`
- Use appropriate log levels: `debug`, `info`, `warn`, `error`, `fatal`
- Use variable inspection for debugging: `#{variable.inspect}`

Example:
```ruby
SolarWindsAPM.logger.debug { "[#{self.class}/#{__method__}] sample_state: #{sample_state.inspect}" }
SolarWindsAPM.logger.warn { "[#{self.class}/#{__method__}] Service Name transformed from #{old} to #{new}" }
```

## Environment Variables

- Use `ENV.fetch('VAR_NAME', 'default')` for optional variables with defaults
- Use `ENV['VAR_NAME']` for checking presence
- Document all environment variables in CONFIGURATION.md
- Priority order: ENV > config file > defaults
- Convert strings to appropriate types (integers, booleans, symbols)

Example:
```ruby
if ENV.fetch('SW_APM_ENABLED', 'true') == 'false'
  # handle disabled case
end

log_level = (ENV['SW_APM_DEBUG_LEVEL'] || SolarWindsAPM::Config[:debug_level] || 3).to_i
```

## String Handling

- Use single quotes for simple strings: `'message'`
- Use double quotes for string interpolation: `"Value: #{value}"`
- Use heredocs for multi-line strings with proper indentation
- Use `String#freeze` for string constants
- Prefer string interpolation over concatenation for readability

## Hash and Symbol Usage

- Use symbols for hash keys: `{ key: value }` or `{ :key => value }`
- Access config hashes with symbols: `SolarWindsAPM::Config[:key]`
- Use `Hash#dig` for safe nested access: `SW_LOG_LEVEL_MAPPING.dig(level, :stdlib)`
- Use `Hash#fetch` with defaults: `hash.fetch(:key, default_value)`

## Ruby Idioms and Best Practices

- Use guard clauses to reduce nesting:
```ruby
return unless condition
return if early_exit_condition
# main logic
```

- Use `||=` for memoization:
```ruby
@settings ||= load_settings
```

- Use `&.` (safe navigation operator) for conditional method calls:
```ruby
value = object&.method&.another_method
```

- Prefer `unless` over `if !` for negative conditions (when readable)
- Use `each_with_object` for transforming collections
- Use `clamp` for range limiting: `value.clamp(min, max)`
- Use range operators efficiently: `value.between?(min, max)`

## Thread Safety

- Use `::Mutex` for protecting shared mutable state:
```ruby
@settings_mutex = ::Mutex.new

@settings_mutex.synchronize do
  @settings = new_settings
end
```

- Document thread safety considerations in comments
- Avoid race conditions when accessing shared state
- Use atomic operations where possible

## Performance Optimization

- Cache expensive computations and regex compilations
- Use `freeze` on constants and immutable objects
- Avoid unnecessary object allocations in hot paths
- Use efficient collection methods (`map`, `select`, `reject` over `each`)
- Prefer `&:method_name` syntax for simple blocks: `array.map(&:to_s)`

## Testing with Minitest

- Use Minitest's spec-style DSL with `describe` and `it` blocks
- Structure tests: `describe 'ClassName' do ... end`
- Name tests descriptively: `it 'does something specific' do ... end`
- Use `let` blocks for test fixtures
- Use Minitest expectations: `assert`, `refute`, `assert_equal`
- Prefer `assert` and `refute` over `assert_equal true/false`

Example:
```ruby
describe 'SolarWindsAPM::TokenBucket' do
  it 'starts full' do
    bucket = SolarWindsAPM::TokenBucket.new(settings)
    assert bucket.consume(2)
  end

  it "can't consume more than it contains" do
    bucket = SolarWindsAPM::TokenBucket.new(settings)
    refute bucket.consume(2)
  end
end
```

## OpenTelemetry Integration

- Use `::OpenTelemetry` prefix for OpenTelemetry SDK classes
- Access current span: `::OpenTelemetry::Trace.current_span`
- Work with context: `::OpenTelemetry::Context.current`
- Use proper span context validation: `span.context.valid?`
- Follow established patterns for span creation and attribute setting

## Configuration Management

- Access config with symbols: `SolarWindsAPM::Config[:key]`
- Set config with validation: `SolarWindsAPM::Config[:key] = value`
- Use symbol values for enabled/disabled states: `:enabled`, `:disabled`
- Validate configuration values in setters
- Log warnings for invalid configurations

## Code Organization

- Keep methods focused and under 25 lines when possible
- Extract complex logic into private methods with descriptive names
- Use meaningful variable names that reflect purpose
- Group related methods together
- Separate public API from implementation details
- Organize require statements at the top of the file

## Struct and Data Classes

- Use `Struct.new` for simple data containers:
```ruby
TokenBucketSettings = Struct.new(:capacity, :rate, :type)
```

- Add methods to Struct subclasses when needed
- Use keyword arguments for Struct initialization when clarity is needed

## Return Values

- Prefer explicit `return` for early returns and clarity
- Implicit returns are acceptable for simple one-line methods
- Return status booleans for operations that can succeed or fail
- Return `nil` explicitly when no meaningful value exists

## Compatibility

- Target Ruby >= 3.1.0 as specified in gemspec
- Avoid using features from newer Ruby versions
- Test compatibility with minimum supported Ruby version
- Document any version-specific behavior

<!-- the source of this file is based on codebase analysis of solarwinds/apm-ruby -->
