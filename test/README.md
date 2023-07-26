# README for the SolarWindsAPM Test Suite

  * [Prerequisites](#prerequisites)
    * [Linux](#linux)
    * [Services](#services)
    * [Oboe](#oboe)
  * [Defining components of a test run](#defining-components-of-a-test-run)
  * [Running Tests](#running-tests)
    * [Run all tests](#run-all-tests)
    * [Run some tests](#run-some-tests)
    * [Run one test from suite, a specific test file, or a specific test](#run-one-test-from-suite,-a-specific-test-file,-or-a-specific-test)
  * [byebug for debugging](#byebug-for-debugging)
  * [Duplication (◔_◔) and missing tests ( •̆௰•̆ )](#duplication-(◔_◔)-and-missing-tests-(-•̆௰•̆-))


## TL:DR
1) start container and services with code base mounted
```bash
bundle exec rake docker
```
2) setup ruby environment
```bash
test/run_otel_tests/ruby_setup.sh
```
3) run all tests in container
```bash
test/run_otel_tests/run_tests.sh
```
4) the output goes to the logs in this repo

search for `FAIL|ERROR` to find the tests that didn't pass

run fewer tests by using the options e.g.
```bash
test/run_otel_tests/run_tests.sh -r 2.7.5 -g gemfiles/unit.gemfile
```
5) fix code and rerun, the code base is mounted in the container ;)

---

The tests for this gem focus on sending the correct information
to the data collector as well as dealing with exceptions when
using the gem.

Many of them are set up in the style of integration tests and rely
on external services or background jobs.

We are providing a Docker setup that makes it easy to run test suites
and debug while writing code. The gem code is shared as a volume in the
docker container so that any changes to the code are reflected
immediately.

## Prerequisites

The following are prerequisites which will be satisfied automatically when
using the provided Docker test setup.

### Linux
The solarwinds_apm gem only runs on Linux because the c-library that
sends data to the collector is only available on Linux.

Therefore the tests need to run in Linux and debugging needs to be
done in Linux.

Please see further down on how to run a single test.

## Defining components of a test run
A single test run is defined by:
* the ruby version (make sure to use the )
* the gemfile
* the database type

This means that the same tests can be run with different ruby versions
or databases. And, the selected gemfile determines which test files will be run.

See `.travis.yml` for the components of the test matrix.

## Running Tests
Since the tests need to run in Linux there is docker setup for
the Mac users and it probably makes sense for Linux users as well,
because it takes care of starting the required services.

### Run all tests
To run all tests:
```bash
bundle exec rake docker_test [alpine|debian|ubuntu|amazonlinux] [{ruby_version}]
```
e.g.
```bash
bundle exec rake docker_test ubuntu 3.1.0
```

>Temporarily commenting out components (e.g. a ruby version) in travis.yml
is a good way to reduce the time of a test run.

Be aware that starting the container takes longer if the Docker image needs to be created first
(+10-15 minutes) because it needs to install three versions of Ruby, which is a pretty
slow process. It is recommended to keep the solarwinds_apm image and only replace
it if there is a change with the Ruby versions required for the tests.

When done with testing, the auxiliary containers can be stopped with:
```bash
rake docker_down
```

### Run some tests
In this case we want to start a docker container and then define
which tests to run from within.
```bash
bundle exec rake docker [alpine|debian|ubuntu|amazonlinux]
```

Setup the docker container (install ruby and other dependencies)
```bash
test/run_otel_tests/ruby_setup.sh
```

In the container check out the options:
```bash
test/run_otel_tests/run_tests.sh -h
```

Example: Run the framework tests with ruby 2.7.5
```bash
test/run_otel_tests/run_tests.sh -r 2.7.5 -g gemfiles/frameworks.gemfile
```

### Run a specific test file, or a specific test
While coding and for debugging it may be helpful to run fewer tests.
To run singe tests the env needs to be set up and use `ruby -I test`

One file:
```bash
rbenv local 3.1.0
export BUNDLE_GEMFILE=gemfiles/unit.gemfile
bundle exec ruby -I test test/component/solarwinds_exporter_test.rb
```

A specific test:
```bash
rbenv global 3.1.0
export BUNDLE_GEMFILE=gemfiles/unit.gemfile
bundle exec ruby -I test test/component/solarwinds_exporter_test.rb -n /test_build_meta_data/
```

Gotcha!

## byebug for debugging

The gem is setup to be debugged with `byebug`, add the following lines in the code for a break:
```ruby
require 'byebug'
byebug
```
See here for docu: https://github.com/deivid-rodriguez/byebug

## Duplication (◔_◔) and missing tests ( •̆௰•̆ )
Sorry, it takes some time to run all the tests. There is
duplication as well as omissions. The test code is a bit of a jungle, so
for now the aim is to get good coverage for added and refactored code and
clean up tests whenever it makes sense.

If you are contributing, please make sure all the tests pass and add
tests for your code, so that it can't be broken.

For questions with testing please contact the main contributor.

## github workflow
Test run on push in github.

Some tests may have to be rerun. It is usually a coordination issue with
writing/reading the text file, that collects the traces. 

If all the tests fail for one Linux or one Ruby version, it should be investigated.
