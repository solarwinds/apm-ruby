# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  class HttpSampler < Sampler
    REQUEST_TIMEOUT = 10 # 10s
    GET_SETTING_DURAION = 60 # 60s

    # we don't need hostname as it's for separating browser and local env
    def initialize(config)
      super(config, SolarWindsAPM.logger)

      @url = config[:collector]
      @service = URI.encode_www_form_component(config[:service]) # service name "Hello world" -> "Hello%20world"
      @headers = config[:headers]

      @hostname = hostname
      @setting_url = URI.join(@url, "./v1/settings/#{@service}/#{@hostname}")

      Thread.new { settings_request }
    end

    private

    # Node.js equivalent: Retrieve system hostname
    # e.g. docker -> docker.swo.ubuntu.development; macos -> NHSDFWSSD
    def hostname
      host = Socket.gethostname
      URI.encode_www_form_component(host)
    end

    def fetch_with_timeout(url, timeout_seconds = nil)
      uri = url
      response = nil

      thread = Thread.new do
        ::OpenTelemetry::Common::Utilities.untraced do
          Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
            request = Net::HTTP::Get.new(uri)
            request['Authorization'] = @headers

            response = http.request(request)
          end
        end
      rescue StandardError => e
        @logger.debug { "Error during request: #{e.message}" }
      end

      thread_join = thread.join(timeout_seconds || REQUEST_TIMEOUT)
      if thread_join.nil?
        @logger.debug { "Request timed out after #{timeout_seconds} seconds" }
        thread.kill
      end

      response
    end

    # a endless loop within a thread (non-blocking)
    def settings_request
      loop do
        @logger.debug { "Retrieving sampling settings from #{@setting_url}" }

        response = fetch_with_timeout(@setting_url)

        begin
          parsed = response&.body ? JSON.parse(response.body) : nil
          @logger.debug { "parsed settings in json: #{parsed.inspect}" }
        rescue JSON::ParserError => e
          @logger.warn { "JSON parsing error: #{e.message}" }
          parsed = nil
        end

        if update_settings(parsed)
          # update the settings before the previous ones expire with some time to spare
          expiry = (parsed['timestamp'].to_i + parsed['ttl'].to_i)
          expiry_timeout = expiry - REQUEST_TIMEOUT - Time.now.to_i
          sleep([0, expiry_timeout].max)
        else
          @logger.warn { 'Retrieved sampling settings are invalid. Ensure proper configuration.' }
          sleep(GET_SETTING_DURAION)
        end
      rescue StandardError => e
        @logger.warn { "Failed to retrieve sampling settings (#{e.message}), tracing will be disabled until valid ones are available." }
        sleep(GET_SETTING_DURAION)
      end
    end
  end
end
