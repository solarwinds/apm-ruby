# Contributing

## Developement Environment Setup

The descriptions below assume you are in the locally cloned project root directory, i.e. `swotel-ruby`.

## Prerequisites

* Docker
* Docker Compose

### Minimal Setup to Build the Gem

Start a standard ruby container with the working tree bind-mounted:
```bash
docker run --rm -it -v $PWD:/work --workdir /work ruby:3.1 bash
```

In the container:
```bash
# install system dependencies, just swig for now
apt update && apt upgrade -y && apt install swig -y

# install project gem dependencies
bundle install

# build the gem
bundle exec rake build_gem
```

### Comprehensive Testing and Debugging Setup

This requires a ruby development environment set up on your laptop, which we'll describe for [rbenv](https://github.com/rbenv/rbenv).  Feel free to use other tools such as RVM.  

#### Install rbenv
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

#### Install and Set Ruby Runtime

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

Set ruby version to use:
```bash
rbenv global 3.1.2   # set the default Ruby version for this machine
# or:
rbenv local 3.1.2    # set the Ruby version for this directory
```

#### Run Test/Debug Containers

Install bundler and project dependencies:
```bash
gem install bundler
bundle install
```

Start the testing/debugging container and supporting services:
```bash
bundle exec rake docker
```

In the container:
```bash
# install project gem dependencies
bundle install

# build the gem
bundle exec rake build_gem

# install the built gem
gem install builds/solarwinds_otel_apm-<version>.gem
```

## Linting

We use rubocop to lint our code.  There's a rake task to help run it:

```bash
# in a dev environment with dependencies installed
bundle exec rake rubocop
```

It will produce the file `rubocop_result.txt`.  Issues found should be addressed prior to commit.

## Testing

Start the testing/debugging container and supporting services:
```bash
bundle exec rake docker
```

In the container:
```bash
# install project gem dependencies
bundle install

# run all tests
test/run_otel_tests/run_tests

# run just the ruby 2.7.5 tests
test/run_otel_tests/run_tests -r 2.7.5
```

### Run a specific test file, or a specific test

While coding and for debugging it may be helpful to run fewer tests.
To run single tests the env needs to be set up and use `ruby -I test`

One file:
```bash
rbenv local 2.7.5
export BUNDLE_GEMFILE=gemfiles/delayed_job.gemfile
export DBTYPE=mysql       # optional, defaults to postgresql
bundle
bundle exec rake cfc           # download, compile oboe_api, and link liboboe
bundle exec ruby -I test test/unit/otel_config_propagator_test.rb
```

A specific test:
```bash
rbenv global 2.7.5
export BUNDLE_GEMFILE=gemfiles/libraries.gemfile
export DBTYPE=mysql
bundle
bundle exec ruby -I test test/unit/otel_config_test.rb -n /test_resolve_propagators_with_defaults/
```
