# Contributing to SolarWinds APM Ruby

Thank you for your interest in contributing to the SolarWinds APM Ruby gem! This document provides guidelines and instructions for contributing to this OpenTelemetry-based Ruby distribution.

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

- **Git** - For version control
- **Ruby** - For running Rake tasks
- **Docker** - (Optional) Required for containerized development and testing
- **Docker Compose** - (Optional) Used for some rake tests that start the container

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

We recommend using [rbenv](https://github.com/rbenv/rbenv) for Ruby version management.

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
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
echo 'eval "$(~/.rbenv/bin/rbenv init - bash)"' >> ~/.bashrc # for bash
echo 'eval "$(~/.rbenv/bin/rbenv init - zsh)"' >> ~/.zshrc   # for zsh
source ~/.bashrc    # for bash
source ~/.zshrc     # for zsh
```

### 2. Install and Configure Ruby

Install Ruby using rbenv, enable rbenv, and set the global Ruby version

```bash
rbenv init
rbenv install -L                # List all available versions
rbenv install 3.1.2             # Install the desired Ruby version
rbenv global 3.1.2              # Set the default Ruby version for this machine
```

### 3. Install Project Dependencies

Install Bundler and configure it for development:

```bash
gem install bundler
bundle install
```

## Development Workflow

### Development Environment

You can use your host machine for building, installing, and testing.

```bash
# e.g. running all test case after update
APM_RUBY_TEST_KEY=your_service_key test/run_tests.sh
```

### Development Environment inside Container

You can use Ubuntu containers with all necessary tools for building, installing, and working with the project.

#### Starting the Development Container

Launch the development container:

```bash
bundle exec rake docker_dev
```

Once inside the container, set up the environment:

```bash
rbenv global <some-version>      # Choose and set the Ruby version (check available versions)
bundle install                   # Install project dependencies
```

The development container provides a complete environment for:

- Building and testing the gem
- Running linting tools
- Debugging issues
- Making code changes

All source code is mounted from your host machine, so changes are immediately reflected in the container.

### Building and Testing the Gem

#### Building the Gem

Build the gem:

```bash
bundle exec rake build_gem                          # Build the gem
gem install builds/solarwinds_apm-<version>.gem     # Install the built gem locally
SW_APM_SERVICE_KEY=<api-token:service-name> irb -r solarwinds_apm # Test the installation by loading the gem
```

Build the gem without rake task:

```bash
gem build solarwinds_apm.gemspec                    # Build the gem
gem install solarwinds_apm-<version>.gem     # Install the built gem locally
SW_APM_SERVICE_KEY=<api-token:service-name> irb -r solarwinds_apm # Test the installation by loading the gem
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

### Running the Complete Test Suite inside Container From the Host Machine

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

We use RuboCop for code style enforcement. Run linting:

```bash
bundle exec rake rubocop
```

This generates a `rubocop_result.txt` file. **All linting issues must be resolved before submitting a pull request.**

## Getting Help

- **Issues**: Check existing issues or create a new one
- **Discussions**: Use GitHub Discussions for questions
- **Documentation**: Refer to our [documentation website](https://documentation.solarwinds.com/en/success_center/observability/content/configure/services/ruby/install.htm)
- **Email**: Contact <technicalsupport@solarwinds.com> for technical support

## Additional Resources

- [OpenTelemetry Ruby Documentation](https://opentelemetry.io/docs/instrumentation/ruby/)
- [SolarWinds Observability Documentation](https://documentation.solarwinds.com/en/success_center/observability/default.htm)
- [Project GitHub Repository](https://github.com/solarwinds/apm-ruby)

Thank you for contributing to SolarWinds APM Ruby! 🙏
