#!/usr/bin/env rake
# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'bundler/gem_tasks'

DOCKER_DEV_CONTAINER = 'ruby_sw_apm_ubuntu_development'

desc 'Open a shell in the ubuntu development container. Reuses the existing container or image
if present, otherwise builds the image and creates the container.'
task :docker do
  name = DOCKER_DEV_CONTAINER
  cmd = if docker_exist?('container', name)
          "docker container start #{name} && docker exec -it #{name} /bin/bash"
        else
          # compose run only builds the image when it does not exist yet
          "docker compose run --service-ports --name #{name} #{name}"
        end
  docker_cmd_execute(cmd)
end

namespace :docker do
  desc 'Build the ubuntu docker image without cache'
  task :build do
    docker_cmd_execute('docker compose build --no-cache')
  end

  desc 'Stop all containers that were started for testing and debugging'
  task :down do
    docker_cmd_execute('docker compose down -v --remove-orphans')
  end

  desc "Run an official docker ruby image with the specified tag. The test suite is launched if
runtests is set to true, else a shell session is started for interactive test runs. The platform
argument can be used to override the image architecture if multi-platform is supported.

tag: any available image tag e.g. 3.2-bookworm, 2.7.5-alpine3.15, etc. default: 3.1-bullseye.
runtests: true or false. default: true.
platform: run image for specified OS/Arch, e.g. linux/amd64. default: none.
env_vars: comma-separated list of environment variables in KEY=VALUE format. default: none.

Example:
  bundle exec rake 'docker:tests[,,,APM_RUBY_TEST_KEY=your_service_key]'
  bundle exec rake 'docker:tests[3.3-rc,,,APM_RUBY_TEST_KEY=your_service_key]'
  bundle exec rake 'docker:tests[,false,,APM_RUBY_TEST_KEY=your_service_key]'
  bundle exec rake 'docker:tests[2.7.6-alpine3.15,,linux/amd64,APM_RUBY_TEST_KEY=your_service_key]'
  bundle exec rake 'docker:tests[3.1-bullseye,true,,APM_RUBY_TEST_KEY=your_service_key]'"
  task :tests, [:tag, :runtests, :platform, :env_vars] do |_, args|
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
end

def docker_exist?(type, name)
  system("docker #{type} inspect #{name}", out: File::NULL, err: File::NULL)
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
  File.write(rubocop_file, '')

  `bundle exec rubocop --auto-correct` if arg2 == 'auto-safe'
  `bundle exec rubocop --auto-correct-all` if arg2 == 'auto-all'
  `bundle exec rubocop > rubocop_result.txt`
  exit 1
end
