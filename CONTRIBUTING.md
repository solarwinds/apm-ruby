# Contributing

## Requirements

The descriptions below assume you are in the locally cloned project root directory, i.e. `apm-ruby`.

Prerequisites

* Docker
* Docker Compose

## Host Machine Setup

You'll need a host environment that can run the various Rake tasks to spin up development and testing containers. The following describes how to do this with [rbenv](https://github.com/rbenv/rbenv).

### 1. Install rbenv

Mac

```bash
brew install rbenv ruby-build
```

Linux

```bash
sudo apt install rbenv
```

Built from source (github)

```bash
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'eval "$(~/.rbenv/bin/rbenv init - bash)"' >> ~/.bashrc # for bash
echo 'eval "$(~/.rbenv/bin/rbenv init - zsh)"' >> ~/.zshrc   # for zsh
```

### 2. Install and Set Ruby Runtime

Install ruby from rbenv:

```bash
# list latest stable versions:
rbenv install -l

# list all local versions:
rbenv install -L

# install a Ruby version:
rbenv install 3.1.2
```

Enable rbenv by following the instructions printed by this command:

```bash
rbenv init
```

Set ruby version to use.  Set this at the global level to prevent `.ruby-version` conflicts within the development container which bind mounts the working tree:

```bash
rbenv global 3.1.2   # set the default Ruby version for this machine
```

### 3. Install Minimal Project Dependencies

Install bundler, configure it to skip unneeded groups, then install the project dependencies to allow working with Rake tasks:

```bash
gem install bundler
bundle config set --local without development test
bundle install
```

Should now be able to list the Rake tasks:

```bash
bundle exec rake -T
```

## Run Development Container

The `solarwinds_apm` gem requires a Linux run time environment. To work on the codebase we set up an Ubuntu container with the tools needed to build, install and work with the project.

Starting the container:

```bash
bundle exec rake docker_dev
```

In the container, set up the environment and project dependencies:

```bash
# choose the ruby version to use, setting it at the global level
rbenv versions
rbenv global <some-version>

# install project gem dependencies
bundle install
```

### Building the Gem

The gem can be built, installed, and run inside the development container:

```bash
# build the gem
bundle exec rake build_gem

# install the built gem
gem install builds/solarwinds_apm-<version>.gem

# load the gem
SW_APM_SERVICE_KEY=<api-token:service-name> irb -r solarwinds_apm
```

### Linting

Use this Rake task to run rubocop inside the development container:

```bash
bundle exec rake rubocop
```

It will produce the file `rubocop_result.txt`.  Issues found should be addressed prior to commit.

## Run Test Containers

On the host machine, you can use the `docker_tests` Rake task to run the test suite, or launch an interactive shell session into the test container to run specific tests or to debug.

### Run Test Suite

Run the test suite (some test cases rely on env `APM_RUBY_TEST_KEY`):

```bash
# run tests in a ruby:3.1.0-bullseye container
bundle exec rake 'docker_tests[,,,APM_RUBY_TEST_KEY=your_service_key]'

# run tests in a ruby:3.2-alpine linux/amd64 container
bundle exec rake 'docker_tests[3.2-alpine,,linux/amd64,APM_RUBY_TEST_KEY=your_service_key]'
```

Test logs are written to the project's `log` directory, which is bind mounted and available on the host machine.

### Launch Interactive Shell

Start an interactive session in the container:

```bash
bundle exec rake 'docker_tests[,false]'
```

In the container, set up the environment:

```bash
test/test_setup.sh
```

To run the full suite (some test cases rely on env `APM_RUBY_TEST_KEY`):

```bash
APM_RUBY_TEST_KEY=your_service_key test/run_tests.sh
```

To run a single test file or single test case:

```bash
# most tests require just the unit.gemfile dependencies
bundle update
bundle exec ruby -I test test/opentelemetry/solarwinds_propagator_test.rb
bundle exec ruby -I test test/opentelemetry/solarwinds_propagator_test.rb -n /trace_state_header/
```
