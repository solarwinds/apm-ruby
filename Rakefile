#!/usr/bin/env rake
# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'rubygems'
require 'fileutils'
require 'net/http'
require 'optparse'
require 'digest'
require 'open-uri'
require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.verbose = false
  t.warning = false
  t.ruby_opts = []
  t.libs << 'test'

  gem_file = ENV['BUNDLE_GEMFILE']&.split('/')&.last

  case gem_file
  when 'unit.gemfile'
    t.test_files = FileList['test/api/*_test.rb'] +
                   FileList['test/solarwinds_apm/*_test.rb'] +
                   FileList['test/opentelemetry/*_test.rb'] +
                   FileList['test/noop/*_test.rb'] +
                   FileList['test/support/*_test.rb'] +
                   FileList['test/sampling/*_test.rb'] -
                   FileList['test/opentelemetry/otlp_processor_*_test.rb']
  end
end

################ Docker Task ################

desc "Run an official docker ruby image with the specified tag. The test suite is launched if
runtests is set to true, else a shell session is started for interactive test runs. The platform
argument can be used to override the image architecture if multi-platform is supported.

tag: any available image tag e.g. 3.2-bookworm, 2.7.5-alpine3.15, etc. default: 3.1-bullseye.
runtests: true or false. default: true.
platform: run image for specified OS/Arch, e.g. linux/amd64. default: none.
env_vars: comma-separated list of environment variables in KEY=VALUE format. default: none.

Example:
  bundle exec rake 'docker_tests[,,,APM_RUBY_TEST_KEY=your_service_key]'
  bundle exec rake 'docker_tests[3.3-rc,,,APM_RUBY_TEST_KEY=your_service_key]'
  bundle exec rake 'docker_tests[,false,,APM_RUBY_TEST_KEY=your_service_key]'
  bundle exec rake 'docker_tests[2.7.6-alpine3.15,,linux/amd64,APM_RUBY_TEST_KEY=your_service_key]'
  bundle exec rake 'docker_tests[3.1-bullseye,true,,APM_RUBY_TEST_KEY=your_service_key]'"
task :docker_tests, [:tag, :runtests, :platform, :env_vars] do |_, args|
  args.with_defaults(tag: '3.1-bullseye', runtests: 'true')
  opt = +' --rm --tty --volume $PWD:/code/ruby-solarwinds --workdir /code/ruby-solarwinds'
  opt << " --platform #{args.platform}" unless args.platform.to_s.empty?

  # Add custom environment variables if provided
  unless args.env_vars.to_s.empty?
    env_vars = args.env_vars.split(',').map(&:strip)
    env_vars.each do |env_var|
      opt << " -e #{env_var}" if env_var.include?('=')
    end
  end

  if args.runtests == 'true'
    opt << ' --entrypoint test/test_setup.sh -e RUN_TESTS=1'
  else
    opt << " --interactive --name ruby_sw_apm_#{args.tag}"
    cmd = '/bin/sh'
  end
  command = "docker run #{opt} ruby:#{args.tag} #{cmd}"
  sh command do |ok, res|
    puts "ok: #{ok}, #{res.inspect}"
  end
end

desc 'Start ubuntu docker container for testing and debugging.'
task docker_dev: [:docker_down] do
  cmd = "docker compose run --service-ports \
  --name ruby_sw_apm_ubuntu_development ruby_sw_apm_ubuntu_development"
  docker_cmd_execute(cmd)
end

desc 'Continue the docker container created last time'
task :docker_con do
  cmd = "docker container start ruby_sw_apm_ubuntu_development &&
          docker exec -it ruby_sw_apm_ubuntu_development /bin/bash"
  docker_cmd_execute(cmd)
end

desc 'Build the ubuntu docker container without cache'
task :docker_build do
  cmd = 'docker compose build --no-cache'
  docker_cmd_execute(cmd)
end

desc 'Stop all containers that were started for testing and debugging'
task :docker_down do
  cmd = 'docker compose down -v --remove-orphans'
  docker_cmd_execute(cmd)
end

def docker_cmd_execute(cmd)
  Dir.chdir('test') do
    sh cmd do |ok, res|
      puts "ok: #{ok}, #{res.inspect}"
    end
  end
end

desc 'Run rubocop and generate result. Run as bundle exec rake rubocop
      If want to safely autocorrect enabled, just use bundle exec rake rubocop auto-safe
      If want to all autocorrect enabled, just use bundle exec rake rubocop auto-all
      If want to specific lint rule for autocorrection, run as bundle exec rubocop -A --only'
task :rubocop do
  _arg1, arg2 = ARGV

  rubocop_file = "#{__dir__}/rubocop_result.txt"
  FileUtils.rm_f(rubocop_file)
  new_file = File.new(rubocop_file, 'w')
  new_file.close

  `bundle exec rubocop --auto-correct` if arg2 == 'auto-safe'
  `bundle exec rubocop --auto-correct-all` if arg2 == 'auto-all'
  `bundle exec rubocop > rubocop_result.txt`
  exit 1
end
