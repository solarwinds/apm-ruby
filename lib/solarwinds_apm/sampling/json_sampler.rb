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
      @logger.debug { "[#{self.class}/#{__method__}] JsonSampler initialized: path=#{@path}, initial_expiry=#{@expiry}" }
      loop_check
    end

    # only json sampler will need to check if the settings.json file
    def should_sample?(params)
      loop_check
      super
    end

    private

    def loop_check
      return if Time.now.to_i + 10 < @expiry # update if we're not within 10s of expiry

      unparsed = nil
      begin
        contents = File.read(@path)
        unparsed = JSON.parse(contents)

        unless unparsed.is_a?(Array) && unparsed.length == 1
          @logger.debug { "[#{self.class}/#{__method__}] Invalid settings file : #{unparsed}" }
          unparsed = nil
        end

      rescue JSON::ParserError => e
        @logger.error { "[#{self.class}/#{__method__}] JSON parsing error in #{@path}: #{e.message}" }
      rescue StandardError => e
        @logger.debug { "[#{self.class}/#{__method__}] Missing or invalid settings file; Error: #{e.message}" }
      end

      return if unparsed.nil?

      parsed = update_settings(unparsed.first)

      if parsed
        @expiry = parsed[:timestamp].to_i + parsed[:ttl].to_i
        @logger.debug { "[#{self.class}/#{__method__}] Settings updated successfully: old_expiry=#{@expiry}, new_expiry=#{new_expiry}, parsed=#{parsed.inspect}" }
      else
        @logger.debug { "[#{self.class}/#{__method__}] Settings update failed, keeping current expiry: #{@expiry}" }
      end
    end
  end
end
