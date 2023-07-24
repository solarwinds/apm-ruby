# Contributing

## Developement Environment Setup

The descriptions below assume you are in the locally cloned project root directory, i.e. `swotel-ruby`.

Prerequisites
* Docker
* Docker Compose

## Minimal Setup to Build the Gem

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

## Comprehensive Testing and Debugging Setup

This requires a ruby development environment set up on your laptop, which we'll describe for [rbenv](https://github.com/rbenv/rbenv).  Feel free to use other tools such as RVM.  

## 1. Install rbenv

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

## 2. Install and Set Ruby Runtime

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

## Run Development Containers

Current support ubuntu development enviornment

Install bundler, configure it to skip unneeded groups then install the project dependencies:
```bash
gem install bundler
bundle config set --local without development test
bundle install
```

Starting the container
```bash
bundle exec rake docker_dev
```

In the container:
```bash
# install project gem dependencies
bundle install

# build the gem
bundle exec rake build_gem

# install the built gem
gem install builds/solarwinds_apm-<version>.gem
```

## Linting

We use rubocop to lint our code.  There's a rake task to help run it:

```bash
# in a dev environment with dependencies installed
bundle exec rake rubocop
```

It will produce the file `rubocop_result.txt`.  Issues found should be addressed prior to commit.

## Testing

### 1. Run Testing Directly With Default Ruby Version (3.1.0)

Install bundler, configure it to skip unneeded groups then install the project dependencies:
```bash
gem install bundler
bundle config set --local without development test
bundle install
```

Starting the test
```bash
bundle exec rake docker_test [alpine|debian|ubuntu|amazonlinux] [{ruby_version}]
```

Example of running ruby 3.1.0 on alpine
```bash
bundle exec rake docker_test alpine 3.1.0
```

### 2. Run Test/Debug Containers

This case is applied if you wish to run specific test.

Install bundler, configure it to skip unneeded groups then install the project dependencies:
```bash
gem install bundler
bundle config set --local without development test
bundle install
```

Start the testing/debugging container and supporting services:
```bash
bundle exec rake docker [alpine|debian|ubuntu|amazonlinux]
```

The default ruby version is 3.1.0, but you can install other ruby version through rbenv e.g. `rbenv install 2.7.0 && rbenv local 2.7.0`


In the container, execute the script:
```bash
test/run_otel_tests/ruby_setup.sh # Install ruby

test/run_otel_tests/run_tests.sh  # Run the all test case

bundle exec ruby -I test test/unit/otel_config_propagator_test.rb # One file

bundle exec ruby -I test test/unit/otel_config_test.rb -n /test_resolve_propagators_with_defaults/  # A specific test
```

### Trouble-shooting

You may need to run `. ~/.profile` again to apply `rbenv` globally to all shell sessions