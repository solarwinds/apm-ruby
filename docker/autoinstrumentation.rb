# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

# Entry point of the autoinstrumentation-ruby image, loaded through RUBYOPT
# (e.g. RUBYOPT="-r /otel-auto-instrumentation-ruby/src/autoinstrumentation").
# solarwinds_apm is required right after Bundler.require so that use_all installs
# instrumentation for the libraries the application has already loaded.

# SolarWindsAPMBundlerPatch
module SolarWindsAPMBundlerPatch
  # Nested module to handle solarwinds_apm initialization logic
  module Initializer
    @mutex = Mutex.new
    @initialized = false

    # Warns if solarwinds_apm or opentelemetry- gems are found in the Gemfile, as they may conflict with auto-instrumentation.
    def self.check_for_bundled_gems
      bundled_gems = Bundler.definition.dependencies.select do |dep|
        dep.name == 'solarwinds_apm' || dep.name.start_with?('opentelemetry-')
      end

      return if bundled_gems.empty?

      gem_names = bundled_gems.map(&:name).sort.join(', ')
      warn '[solarwinds_apm] WARNING: Detected solarwinds_apm/OpenTelemetry gems in your Gemfile: ' \
           "#{gem_names}. When using the autoinstrumentation-ruby image, these gems are loaded " \
           'from the image gem path, NOT from your bundle. The gem versions in your Gemfile/Gemfile.lock ' \
           'are not used and may cause version conflicts or unexpected behavior. Please remove these ' \
           'gems from your Gemfile when using the autoinstrumentation-ruby image.'
    rescue StandardError => e
      warn "[solarwinds_apm] WARNING: Unable to check Gemfile for bundled gems: #{e.message}" if ENV['OTEL_RUBY_AUTO_INSTRUMENTATION_DEBUG'] == 'true'
    end

    # Requires solarwinds_apm exactly once; solarwinds_apm configures the OpenTelemetry SDK on load.
    def self.require_solarwinds_apm
      @mutex.synchronize do
        return if @initialized

        @initialized = true

        begin
          check_for_bundled_gems
          require 'solarwinds_apm'
        rescue StandardError, LoadError => e
          warn "[solarwinds_apm] Auto-instrumentation failed to initialize. Error: #{e.message}"
        end
      end
    end
  end

  # Overrides Bundler::Runtime#require to load solarwinds_apm after the application gems are required.
  def require(...)
    result = super
    Initializer.require_solarwinds_apm
    result
  end
end

require 'bundler'

ADDITIONAL_LIB_GEM_ALLOWLIST = %w[
  googleapis-common-protos-types
  google-protobuf
].freeze

parse_env_list = lambda do |key|
  ENV[key].to_s.split(',').map(&:strip).reject(&:empty?)
end

# /otel-auto-instrumentation-ruby is default path for otel operator (ruby.go)
# If requires different gem path to load gem, set env OTEL_RUBY_ADDITIONAL_GEM_PATH
gem_path = ENV['OTEL_RUBY_ADDITIONAL_GEM_PATH'] || '/otel-auto-instrumentation-ruby'
gem_path = Gem.dir unless Dir.exist?(gem_path)

gem_entries = Dir.glob("#{gem_path}/gems/*")

# googleapis-common-protos-types and google-protobuf are dependencies for otlp exporters
sw_lib_path = gem_entries.select do |file_path|
  gem_dir_name = File.basename(file_path)
  gem_dir_name.start_with?('opentelemetry-', 'solarwinds_apm-')
end

disallowed_lib_paths = parse_env_list.call('DISALLOWED_LIB_PATH')
allowed_additional_lib_gems = ADDITIONAL_LIB_GEM_ALLOWLIST - disallowed_lib_paths

additional_lib_path = gem_entries.select do |file_path|
  gem_dir_name = File.basename(file_path)
  allowed_additional_lib_gems.any? { |gem_name| gem_dir_name.start_with?("#{gem_name}-") }
end

# unshift file_path add solarwinds_apm and opentelemetry component at the top of $LOAD_PATH
sw_lib_path.each { |file_path| $LOAD_PATH.unshift("#{file_path}/lib") }
additional_lib_path.each { |file_path| $LOAD_PATH.unshift("#{file_path}/lib") }

warn "Loading the gem path from #{gem_path}\n$LOAD_PATH after unshift: #{$LOAD_PATH.join(',')}" if ENV['OTEL_RUBY_AUTO_INSTRUMENTATION_DEBUG'] == 'true'

Bundler::Runtime.prepend(SolarWindsAPMBundlerPatch)

Bundler.require if ENV['OTEL_RUBY_REQUIRE_BUNDLER'] == 'true'
