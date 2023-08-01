TODO: REMOVE THIS FILE after looking at following

Is this still the way? search for `FAIL|ERROR` to find the tests that didn't pass

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
