# frozen_string_literal: true

source 'https://rubygems.org'

gem 'rake'

group :development, :test do
  if RUBY_VERSION < '3.0.0'
    gem 'ffi', '<= 1.16.3' # set this version due to ffi 1.17.0 need rubygems version > 3 (https://rubygems.org/gems/ffi/versions/1.17.0-arm-linux-musl)
    gem 'google-protobuf', '< 3.25.4'
  elsif RUBY_VERSION < '3.1.0'
    gem 'ffi', '<= 1.17'
  else
    gem 'ffi'
  end
  gem 'benchmark-ips', '>= 2.7.2'
  gem 'bson'
  gem 'byebug', '>= 8.0.0'
  gem 'e2mmap'
  gem 'get_process_mem'
  gem 'irb', '>= 1.0.0'
  gem 'logging'
  gem 'lumberjack'
  gem 'memory_profiler'
  gem 'minitest', '< 5.25.0'
  gem 'minitest-debugger', require: false
  gem 'minitest-focus', '>= 1.1.2'
  gem 'minitest-hooks', '>= 1.5.0'
  gem 'minitest-reporters', '< 1.0.18'
  gem 'mocha'
  gem 'rack-cache'
  gem 'rack-test'
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rake', require: false
  gem 'code-scanning-rubocop', '~> 0.6.1'
  gem 'simplecov', require: false, group: :test
  gem 'simplecov-console', require: false, group: :test
  gem 'webmock' if RUBY_VERSION >= '2.0.0'
  gem 'base64' if RUBY_VERSION >= '3.4.0'

  gem 'opentelemetry-propagator-b3'
  gem 'opentelemetry-test-helpers'

  gemspec
end
