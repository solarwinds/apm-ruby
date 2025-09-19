# Contributing to SolarWinds APM Ruby

Thank you for your interest in contributing to the SolarWinds APM Ruby gem! This document provides guidelines and instructions for contributing to this OpenTelemetry-based Ruby distribution.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [Code Quality](#code-quality)
- [Getting Help](#getting-help)

## Code of Conduct

By participating in this project, you agree to abide by our Code of Conduct. Please treat all community members with respect and create a welcoming environment for everyone.

## How to Contribute

We welcome various types of contributions:

- **Bug reports**: Help us identify and fix issues
- **Feature requests**: Suggest new functionality or improvements
- **Documentation**: Improve our docs, guides, and examples
- **Code contributions**: Bug fixes, new features, performance improvements
- **Testing**: Add test coverage or improve existing tests

## Development Setup

### Prerequisites

Before you begin, ensure you have the following installed on your system:

- **Docker** - Required for containerized development and testing
- **Docker Compose** - Used for orchestrating multi-container setups
- **Git** - For version control
- **Ruby** - For running Rake tasks

> **Note:** All development work is done in Docker containers, so you don't need Ruby installed on your host machine, but it's helpful for running Rake tasks.

The instructions below assume you are in the locally cloned project root directory (`apm-ruby`).

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

## Host Machine Setup

For development, you'll need a host environment capable of running Rake tasks to manage development and testing containers. We recommend using [rbenv](https://github.com/rbenv/rbenv) for Ruby version management.

### 1. Install rbenv

Choose the installation method that works best for your system:

**macOS (using Homebrew):**
```bash
brew install rbenv ruby-build
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt install rbenv
```

**Build from source:**
```bash
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'eval "$(~/.rbenv/bin/rbenv init - bash)"' >> ~/.bashrc # for bash
echo 'eval "$(~/.rbenv/bin/rbenv init - zsh)"' >> ~/.zshrc   # for zsh
```

### 2. Install and Configure Ruby

Install Ruby using rbenv:

```bash
# List latest stable versions
rbenv install -l

# List all available versions
rbenv install -L

# Install the desired Ruby version
rbenv install 3.1.2
```

Enable rbenv by following the initialization instructions:

```bash
rbenv init
```

Set the global Ruby version (this prevents conflicts within development containers):

```bash
rbenv global 3.1.2   # Set the default Ruby version for this machine
```

### 3. Install Project Dependencies

Install Bundler and configure it for development:

```bash
gem install bundler
bundle config set --local without development test
bundle install
```

Verify the setup by listing available Rake tasks:

```bash
bundle exec rake -T
```

You should see tasks like `docker_dev`, `docker_tests`, `build_gem`, etc.

## Development Workflow

### Setting Up the Development Environment

The `solarwinds_apm` gem requires a Linux runtime environment. We use Ubuntu containers with all necessary tools for building, installing, and working with the project.

#### Starting the Development Container

Launch the development container:

```bash
bundle exec rake docker_dev
```

Once inside the container, set up the environment:

```bash
# Choose and set the Ruby version (check available versions)
rbenv versions
rbenv global <some-version>

# Install project dependencies
bundle install
```

#### Working in the Development Container

The development container provides a complete environment for:
- Building and testing the gem
- Running linting tools
- Debugging issues
- Making code changes

All source code is mounted from your host machine, so changes are immediately reflected in the container.

### Building and Testing the Gem

#### Building the Gem

Build the gem within the development container:

```bash
# Build the gem
bundle exec rake build_gem

# Install the built gem locally
gem install builds/solarwinds_apm-<version>.gem

# Test the installation by loading the gem
SW_APM_SERVICE_KEY=<api-token:service-name> irb -r solarwinds_apm
```

#### Making Changes

1. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** in the appropriate files under `lib/`

3. **Write or update tests** in the `test/` directory

4. **Test your changes** (see Testing section below)

5. **Run linting** to ensure code quality

## Testing

> **Note:** Some tests require the `APM_RUBY_TEST_KEY` environment variable. Contact the maintainers if you need access to a test key.

### Running Tests

**Full test suite:**
```bash
APM_RUBY_TEST_KEY=your_service_key test/run_tests.sh
```

**Single test file:**
```bash
# Most tests require only the unit.gemfile dependencies
bundle update
bundle exec ruby -I test test/opentelemetry/solarwinds_propagator_test.rb
```

**Single test case:**
```bash
bundle exec ruby -I test test/opentelemetry/solarwinds_propagator_test.rb -n /trace_state_header/
```

### Running the Complete Test Suite From the Host Machine

Execute the full test suite from the host machine:

```bash
# Run tests in Ruby 3.1.0 bullseye container
bundle exec rake 'docker_tests[,,,APM_RUBY_TEST_KEY=your_service_key]'

# Run tests in Ruby 3.2 Alpine container for ARM64
bundle exec rake 'docker_tests[3.2-alpine,,linux/amd64,APM_RUBY_TEST_KEY=your_service_key]'
```

Test logs are written to the `log/` directory and are available on the host machine.

### Test Organization

Tests are organized in the `test/` directory:
- `test/api/` - API-related tests
- `test/opentelemetry/` - OpenTelemetry integration tests
- `test/patch/` - Instrumentation patch tests
- `test/sampling/` - Sampling logic tests
- `test/support/` - Test utilities and helpers

## Code Quality

### Linting

We use RuboCop for code style enforcement. Run linting in the development container:

```bash
bundle exec rake rubocop
```

This generates a `rubocop_result.txt` file. **All linting issues must be resolved before submitting a pull request.**

## Getting Help

- **Issues**: Check existing issues or create a new one
- **Discussions**: Use GitHub Discussions for questions
- **Documentation**: Refer to our [documentation website](https://documentation.solarwinds.com/en/success_center/observability/content/configure/services/ruby/install.htm)
- **Email**: Contact technicalsupport@solarwinds.com for technical support

## Additional Resources

- [OpenTelemetry Ruby Documentation](https://opentelemetry.io/docs/instrumentation/ruby/)
- [SolarWinds Observability Documentation](https://documentation.solarwinds.com/en/success_center/observability/default.htm)
- [Project GitHub Repository](https://github.com/solarwinds/apm-ruby)

Thank you for contributing to SolarWinds APM Ruby! 🙏
