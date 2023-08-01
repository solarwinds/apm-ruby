# Contributing

## Requirements

The descriptions below assume you are in the locally cloned project root directory, i.e. `swotel-ruby`.

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
```
rbenv init
```

Set ruby version to use.  Set this at the global level to prevent `.ruby-version` conflicts within the development container which bind mounts the working tree:
```bash
rbenv global 3.1.2   # set the default Ruby version for this machine
```

### 3. Install Minimal Project Dependencies

Install bundler, configure it to skip unneeded groups (again, at the global level to prevent conflicts within the development container), then install the project dependencies to allow working with Rake tasks:
```bash
gem install bundler
bundle config set --global without development test
bundle install
```

Should now be able to list the Rake tasks:
```
bundle exec rake -T
```

## Run Development Container

The `solarwinds_apm` gem requires a Linux runtime environment, so to work on the codebase we use an Ubuntu container that's set up with tools needed to build, install and work with the project.

Starting the container:
```bash
bundle exec rake docker_dev
```

In the container:
```bash
# choose the ruby version to use, setting it at the global level
rbenv versions
rbenv global <some-version>

# install project gem dependencies
bundle install
```

The gem can be built, installed, and ran inside the container:
```bash
# build the gem
bundle exec rake build_gem

# install the built gem
gem install builds/solarwinds_apm-<version>.gem

# load the gem
SW_APM_SERVICE_KEY=<api-token:service-name> irb -r solarwinds_apm
```

## Run Test Containers

On the host machine, you can run tests several ways.

### Run Testing Directly With Default Ruby Version (3.1.0)

Starting the test
```bash
bundle exec rake docker_tests
```

Example of running ruby 3.1.0 on alpine
```bash
bundle exec rake docker_tests[alpine]
```

### Run Test/Debug Containers

This section is applied if you wish to run specific test.

Start the testing/debugging container and supporting services:
```bash
bundle exec rake docker [alpine|debian]
```

In the container, execute the script:
```bash
test/test_setup.sh # Setup testing enviornment

test/run_tests.sh  # Run the all test case

bundle exec ruby -I test test/unit/otel_config_propagator_test.rb # One file

bundle exec ruby -I test test/unit/otel_config_test.rb -n /test_resolve_propagators_with_defaults/  # A specific test
```

## Linting

We use rubocop to lint our code.  In the development container, use this rake task to run it:
```bash
# in a dev environment with dependencies installed
bundle exec rake rubocop
```

It will produce the file `rubocop_result.txt`.  Issues found should be addressed prior to commit.
