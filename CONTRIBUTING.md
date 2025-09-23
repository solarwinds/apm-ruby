# Contributing to SolarWinds APM Ruby

Thank you for your interest in contributing to the SolarWinds APM Ruby gem! This document provides guidelines and instructions for contributing to this OpenTelemetry-based Ruby distribution.

## How to Contribute

We welcome various types of contributions:

- **Bug reports**: Help us identify and fix issues
- **Feature requests**: Suggest new functionality or improvements
- **Documentation**: Improve our docs, guides, and examples
- **Code contributions**: Bug fixes, new features, performance improvements
- **Testing**: Add test coverage or improve existing tests

## Development Environment Setup

### Prerequisites

Before you begin, ensure you have the following installed:

- **Git** - For version control
- **rbenv** - For Ruby version management (see [rbenv installation guide](https://github.com/rbenv/rbenv#installation))
- **Ruby** - Install via rbenv
- **Docker** - (Optional)

### Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:

   ```bash
   git clone https://github.com/YOUR_USERNAME/apm-ruby.git
   cd apm-ruby
   ```

3. **Add the upstream remote**:

   ```bash
   git remote add upstream https://github.com/solarwinds/apm-ruby.git
   ```

### Setup Ruby Environment

1. **Install Ruby** using rbenv (install appropriate version as needed):

   ```bash
   rbenv install 3.1.2
   rbenv local 3.1.2  # or rbenv global 3.1.2
   ```

2. **Install dependencies** with isolated vendoring:

   ```bash
   gem install bundler
   bundle install --path vendor/bundle
   ```

3. **Verify setup** by listing available rake tasks:

   ```bash
   bundle exec rake -T
   ```

   You should see various available tasks for building, testing, and linting.

## Development Workflow

### Making Changes

1. **Create a feature branch**:

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** in the appropriate files under `lib/`

3. **Write or update tests** in the `test/` directory

### Testing Your Changes

#### Load Changes Interactively

Test your changes without building a gem:

```bash
bundle exec irb -Ilib -r solarwinds_apm
```

This loads your source code changes directly for quick testing and debugging.

#### Running Tests

> **Note:** Some tests require the `APM_RUBY_TEST_KEY` environment variable. Contact the maintainers if you need access to a test key.

**Single test file:**

```bash
bundle exec ruby -I test test/opentelemetry/solarwinds_propagator_test.rb
```

**Single test case:**

```bash
bundle exec ruby -I test test/opentelemetry/solarwinds_propagator_test.rb -n /trace_state_header/
```

**Local test suite (run all test file):**

```bash
APM_RUBY_TEST_KEY=your_service_key test/run_tests.sh
```

#### Code Quality

Run RuboCop for code style enforcement:

```bash
bundle exec rake rubocop
```

All linting issues must be resolved before submitting a pull request.

## Advanced Setup (Optional)

### Development Environment inside Container

For complex debugging or if you prefer working in a containerized environment, you can use Ubuntu containers with all necessary tools:

```bash
bundle exec rake docker_dev
```

Once inside the container:

```bash
rbenv global <version>      # Set Ruby version
bundle install             # Install dependencies
```

The development container provides a complete isolated environment with all source code mounted from your host machine.

### Full Regression Testing

Run the complete test suite in containers (from host machine):

```bash
# Run tests in Ruby 3.1.0 bullseye container
bundle exec rake 'docker_tests[,,,APM_RUBY_TEST_KEY=your_service_key]'

# Run tests in Ruby 3.2 Alpine container for ARM64
bundle exec rake 'docker_tests[3.2-alpine,,linux/amd64,APM_RUBY_TEST_KEY=your_service_key]'
```

Test logs are written to the `log/` directory.

## Additional Resources

- [OpenTelemetry Ruby Documentation](https://opentelemetry.io/docs/instrumentation/ruby/)
- [SolarWinds Observability Documentation](https://documentation.solarwinds.com/en/success_center/observability/default.htm)
- [Project GitHub Repository](https://github.com/solarwinds/apm-ruby)

Thank you for contributing to SolarWinds APM Ruby! 🙏
