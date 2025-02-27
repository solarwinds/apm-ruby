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
                   FileList['test/ext/*_test.rb'] +
                   FileList['test/support/*_test.rb']
  end
end

################ Docker Task ################

desc "Run an official docker ruby image with the specified tag. The test suite is launched if
runtests is set to true, else a shell session is started for interactive test runs. The platform
argument can be used to override the image architecture if multi-platform is supported.

tag: any available image tag e.g. 3.2-bookworm, 2.7.5-alpine3.15, etc. default: 3.1-bullseye.
runtests: true or false. default: true.
platform: run image for specified OS/Arch, e.g. linux/amd64. default: none.

Example:
  bundle exec rake docker_tests
  bundle exec rake 'docker_tests[3.3-rc]'
  bundle exec rake 'docker_tests[,false]'
  bundle exec rake 'docker_tests[2.7.6-alpine3.15,,linux/amd64]'"
task :docker_tests, [:tag, :runtests, :platform] do |_, args|
  args.with_defaults(tag: '3.1-bullseye', runtests: 'true')
  opt = +' --rm --tty --volume $PWD:/code/ruby-solarwinds --workdir /code/ruby-solarwinds'
  opt << " --platform #{args.platform}" unless args.platform.to_s.empty?
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

################ Build Gem Task ################

desc 'alias for fetch_oboe_file_from_staging'
task :fetch do
  Rake::Task['fetch_oboe_file'].invoke('stg')
end

desc 'fetch oboe file from different environment'
task :fetch_oboe_file, [:env] do |_t, args|
  abort('Missing env argument (abort)') if args['env'].nil? || args['env'].empty?

  begin
    swig_version = `swig -version`
  rescue StandardError => e
    swig_version = ''
    puts "Error getting swig version: #{e.message}"
  end
  swig_valid_version = swig_version.scan(/swig version [34].\d*.\d*/i)
  if swig_valid_version.empty?
    warn '== ERROR ================================================================='
    warn "Could not find required swig version > 3.0.8, found #{swig_version.inspect}"
    warn 'Please install swig "> 3.0.8" and try again.'
    warn '=========================================================================='
    raise
  else
    warn "+++++++++++ Using #{swig_version.strip.split("\n")[0]}"
  end

  ext_src_dir = File.expand_path('ext/oboe_metal/src')
  ext_lib_dir = File.expand_path('ext/oboe_metal/lib')
  oboe_version = File.read(File.join(ext_src_dir, 'VERSION')).strip

  case args['env']
  when 'dev'
    oboe_dir = 'https://solarwinds-apm-staging.s3.us-west-2.amazonaws.com/apm/c-lib/nightly/'
    puts 'Fetching c-lib from DEVELOPMENT'
    puts 'This is an unstable build and this gem should only be used for testing'
  when 'stg'
    oboe_dir = "https://agent-binaries.global.st-ssp.solarwinds.com/apm/c-lib/#{oboe_version}"
    puts "Fetching c-lib from STAGING !!!!!! C-Lib VERSION: #{oboe_version} !!!!!!!"
  when 'prod'
    oboe_dir = "https://agent-binaries.cloud.solarwinds.com/apm/c-lib/#{oboe_version}"
    puts "Fetching c-lib from PRODUCTION !!!!!! C-Lib VERSION: #{oboe_version} !!!!!!!"
  end

  # remove all oboe* files, they may hang around because of name changes
  Dir.glob(File.join(ext_src_dir, 'oboe*')).each do |file|
    puts "deleting #{file}"
    File.delete(file)
  end

  # oboe and bson header files
  FileUtils.mkdir_p(File.join(ext_src_dir, 'bson'))
  files = %w[bson/bson.h bson/platform_hacks.h
             oboe.h oboe_api.h oboe_api.cpp oboe_debug.h oboe.i]

  fetch_file_from_cloud(files, oboe_dir, ext_src_dir, 'include')

  sha_files = ['liboboe-1.0-lambda-x86_64.so.sha256',
               'liboboe-1.0-lambda-aarch64.so.sha256',
               'liboboe-1.0-x86_64.so.sha256',
               'liboboe-1.0-aarch64.so.sha256',
               'liboboe-1.0-alpine-x86_64.so.sha256',
               'liboboe-1.0-alpine-aarch64.so.sha256']

  fetch_file_from_cloud(sha_files, oboe_dir, ext_lib_dir)

  FileUtils.cd(ext_src_dir) do
    sh 'swig -c++ -ruby -module oboe_metal -o oboe_swig_wrap.cc oboe.i'
    FileUtils.rm('oboe.i') if args['env'] != 'prod'
  end

  puts 'Fetching finished.'
end

def fetch_file_from_cloud(files, oboe_dir, dest_dir, folder = '')
  files.each do |filename|
    remote_file = File.join(oboe_dir, folder, filename)
    local_file  = File.join(dest_dir, filename)

    puts "fetching #{remote_file}"
    puts "      to #{local_file}"

    begin
      IO.copy_stream(URI.parse(remote_file).open, local_file)
    rescue StandardError => e
      puts "File #{remote_file} missing. #{e.message}"
    end
  end
end

desc 'Build and publish to Rubygems'
# !!! publishing requires gem >=3.0.5 !!!
# Don't run with Ruby versions < 2.7 they have gem < 3.0.5
task :build_and_publish_gem do
  gemspec_file = 'solarwinds_apm.gemspec'
  gemspec = Gem::Specification.load(gemspec_file)
  gem_file = "#{gemspec.full_name}.gem"

  exit 1 unless system('gem', 'build', gemspec_file)

  exit 1 if ENV['GEM_HOST_API_KEY'] && !system('gem', 'push', gem_file)
end

desc "Build the gem's c extension"
task :compile do
  puts "== Building the c extension against Ruby #{RUBY_VERSION}"

  pwd      = Dir.pwd
  ext_dir  = File.expand_path('ext/oboe_metal')
  final_so = File.expand_path('lib/libsolarwinds_apm.so')
  so_file  = File.expand_path('ext/oboe_metal/libsolarwinds_apm.so')

  Dir.chdir ext_dir
  sh "#{Gem.ruby} extconf.rb"
  sh '/usr/bin/env make'

  FileUtils.rm_f(final_so)

  if File.exist?(so_file)
    FileUtils.mv(so_file, final_so)
    Dir.chdir(pwd)
    puts "== Extension built and moved to #{final_so}"
  else
    Dir.chdir(pwd)
    puts '!! Extension failed to build (see above). Have the required binary and header files been fetched?'
    puts '!! Try the tasks in this order: clean > fetch > compile'
  end
end

desc 'Clean up extension build files'
task :clean do
  pwd     = Dir.pwd
  ext_dir = File.expand_path('ext/oboe_metal')
  symlinks = [
    File.expand_path('lib/libsolarwinds_apm.so'),
    File.expand_path('ext/oboe_metal/lib/liboboe.so'),
    File.expand_path('ext/oboe_metal/lib/liboboe-1.0.so.0')
  ]

  symlinks.each do |symlink|
    FileUtils.rm_f symlink
  end
  Dir.chdir ext_dir
  sh '/usr/bin/env make clean' if File.exist? 'Makefile'

  FileUtils.rm_f 'src/oboe_swig_wrap.cc'
  Dir.chdir pwd
end

desc 'Remove all built files and extensions'
task :distclean do
  pwd     = Dir.pwd
  ext_dir = File.expand_path('ext/oboe_metal')
  mkmf_log = File.expand_path('ext/oboe_metal/mkmf.log')
  symlinks = [
    File.expand_path('lib/libsolarwinds_apm.so'),
    File.expand_path('ext/oboe_metal/lib/liboboe.so'),
    File.expand_path('ext/oboe_metal/lib/liboboe-1.0.so.0')
  ]

  if File.exist? mkmf_log
    symlinks.each do |symlink|
      FileUtils.rm_f symlink
    end
    Dir.chdir ext_dir
    sh '/usr/bin/env make distclean' if File.exist? 'Makefile'

    Dir.chdir pwd
  else
    puts 'Nothing to distclean. (nothing built yet?)'
  end
end

desc 'Rebuild the gem c extension without fetching the oboe files, without recreating the swig wrapper'
task recompile: %i[distclean compile]

desc 'Build the gem c extension ...'
task cfc: %i[clean fetch compile]

desc 'Build gem locally for testing'
task :build_gem do
  puts "\n=== building for MRI ===\n"
  FileUtils.mkdir_p('builds') if Dir['builds'].empty?
  File.delete('Gemfile.lock') if Dir['Gemfile.lock'].size == 1

  puts "\n=== install required dependencies ===\n"
  system('bundle install --without development --without test')

  puts "\n=== clean & compile & build ===\n"
  Rake::Task['distclean'].execute
  Rake::Task['fetch_oboe_file'].invoke('prod')
  system('gem build solarwinds_apm.gemspec')

  gemname = Dir['solarwinds_apm*.gem'].first
  FileUtils.mv(gemname, 'builds/')

  built_gem = Dir['builds/solarwinds_apm*.gem']

  puts "\n=== last 5 built gems ===\n"
  puts built_gem

  puts "\n=== SHA256 ===\n"
  system("shasum -a256 #{built_gem.first}")

  puts "\n=== Finished ===\n"
end

def find_or_build_gem(version)
  abort('No version specified.') if version.to_s.empty?

  gems = Dir["builds/solarwinds_apm-#{version}.gem"]
  gem_to_push = nil
  if gems.empty?
    Rake::Task['build_gem'].execute
    gem_to_push = Dir['builds/solarwinds_apm*.gem'].first
  else
    gem_to_push = gems.first
  end

  puts "\n=== Gem will be pushed #{gem_to_push} ==="
  gem_to_push_version = gem_to_push&.match(/-\d*.\d*.\d*/).to_s.delete!('-')
  gem_to_push_version = gem_to_push&.match(/-\d*.\d*.\d*.prev[0-9]*/).to_s.delete!('-') if version.include? 'prev'

  abort('Could not find the required gem file.') if gem_to_push.nil? || gem_to_push_version != version

  gem_to_push
end

# need set the credentials under ~/.gem/credentials
# for download, easiest way is to set BUNDLE_RUBYGEMS__PKG__GITHUB__COM
# but there are other auth methods. see more on https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-rubygems-registry
desc 'Push to github package. Run as bundle exec rake build_gem_push_to_github_package[<version>]'
task :push_gem_to_github_package, [:version] do |_, args|
  exit 1 unless system('gem', 'push', '--key', 'github', '--host', 'https://rubygems.pkg.github.com/solarwinds',
                       "builds/solarwinds_apm-#{args[:version]}.gem")
  puts "\n=== Finished ===\n"
end

desc 'Build gem for github package'
task :build_gem_for_github_package, [:version] do |_, args|
  find_or_build_gem(args[:version])
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

desc 'Remove all the logs generated from run_test.sh'
task :cleanup_logs do
  `rm log/testrun_*`
  `rm log/test_direct_*`
  `rm log/postgresql/postgresql-*`
  puts 'Log cleaned.'
end
