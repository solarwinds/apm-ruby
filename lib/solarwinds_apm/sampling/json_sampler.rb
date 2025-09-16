# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  class JsonSampler < Sampler
    DEFAULT_PATH = File.join(Dir.tmpdir, 'solarwinds-apm-settings.json')

    def initialize(config, path = nil)
      super(config, SolarWindsAPM.logger)

      @path = path || DEFAULT_PATH
      @expiry = Time.now.to_i
      @last_mtime = nil
      @logger.debug { "[#{self.class}/#{__method__}] JsonSampler initialized: path=#{@path}, initial_expiry=#{@expiry}" }
      loop_check
    end

    # only json sampler will need to check if the settings.json file
    def should_sample?(params)
      loop_check
      super
    end

    private

    # multi-thread is rare in lambda environment,
    # here we don't use mutex to guard the execution
    def loop_check
      return if Time.now.to_i < @expiry - 10

      # 1. Read and parse settings from the file.
      begin
        current_mtime = File.mtime(@path)
        return if @last_mtime && current_mtime == @last_mtime

        settings_data = JSON.parse(File.read(@path))
        @last_mtime = current_mtime
      rescue Errno::ENOENT
        # File doesn't exist due to timing, missing collector, etc
        @logger.error { "[#{self.class}##{__method__}] Settings file not found at #{@path}." }
        return
      rescue JSON::ParserError => e
        @logger.error { "[#{self.class}##{__method__}] JSON parsing error in #{@path}: #{e.message}" }
        return
      end

      # 2. Validate the structure of the parsed settings.
      unless settings_data.is_a?(Array) && settings_data.length == 1
        @logger.error { "[#{self.class}##{__method__}] Invalid settings file content: #{settings_data.inspect}" }
        return
      end

      # 3. Attempt to update the settings.
      if (new_settings = update_settings(settings_data.first))
        @expiry = new_settings[:timestamp].to_i + new_settings[:ttl].to_i
        @logger.debug { "[#{self.class}##{__method__}] Settings #{new_settings} updated successfully. New expiry: #{@expiry}" }
      else
        @logger.debug { "[#{self.class}##{__method__}] Settings update failed, keeping current expiry: #{@expiry}" }
      end
    end
  end
end
