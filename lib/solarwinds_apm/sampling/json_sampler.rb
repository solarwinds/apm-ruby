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
      loop_check
    end

    # only json sampler will need to check if the settings.json file
    # updated or not from collector extention
    def should_sample?(params)
      loop_check
      super
    end

    private

    def loop_check
      # Update if we're within 10s of expiry
      return if Time.now.to_i + 10 < @expiry

      begin
        contents = File.read(@path)
        unparsed = JSON.parse(contents)
      rescue StandardError => e
        @logger.debug { "missing or invalid settings file; Error: #{e.message}" }
        return
      end

      unless unparsed.is_a?(Array) && unparsed.length == 1
        @logger.debug { "invalid settings file : #{unparsed}" }
        return
      end

      parsed = update_settings(unparsed.first)
      @logger.debug { "update_settings: #{parsed}" }
      @expiry = parsed[:timestamp].to_i + parsed[:ttl].to_i if parsed
    end
  end
end
