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

      @pid = nil
      @thread = nil

      @logger.debug { "[#{self.class}/#{__method__}] HttpSampler initialized: url=#{@url}, service=#{@service}, hostname=#{@hostname}, setting_url=#{@setting_url}" }

      reset_on_fork
    end

    # restart the settings request thread after forking
    def should_sample?(params)
      reset_on_fork
      super
    end

    def reset_on_fork
      pid = Process.pid
      return if @pid == pid

      @pid = pid
      @thread = Thread.new { settings_request }
      @logger.debug { "[#{self.class}/#{__method__}] Restart the settings_request thread in process: #{@pid}." }
    rescue ThreadError => e
      @logger.error { "[#{self.class}/#{__method__}] Unexpected error in HttpSampler#reset_on_fork: #{e.message}" }
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
      timeout = timeout_seconds || REQUEST_TIMEOUT
      response = nil

      begin
        ::OpenTelemetry::Common::Utilities.untraced do
          Net::HTTP.start(uri.host, uri.port,
                          use_ssl: uri.scheme == 'https',
                          open_timeout: timeout,
                          read_timeout: timeout) do |http|
            request = Net::HTTP::Get.new(uri)
            request['Authorization'] = @headers
            response = http.request(request)
          end
        end
      rescue Net::ReadTimeout, Net::OpenTimeout
        @logger.debug { "Request timed out after #{timeout} seconds" }
      rescue StandardError => e
        @logger.debug { "Error during request: #{e.message}" }
      end

      response
    end

    # a endless loop within a thread (non-blocking)
    def settings_request
      @logger.debug { "[#{self.class}/#{__method__}] Starting settings request loop" }
      sleep_duration = GET_SETTING_DURAION
      loop do
        response = fetch_with_timeout(@setting_url)

        # Check for nil response from timeout
        unless response&.is_a?(Net::HTTPSuccess)
          @logger.warn { "[#{self.class}/#{__method__}] Failed to retrieve settings due to timeout." }
          next
        end

        parsed = JSON.parse(response.body)

        if update_settings(parsed)
          # update the settings before the previous ones expire with some time to spare
          expiry = (parsed['timestamp'].to_i + parsed['ttl'].to_i)
          expiry_timeout = expiry - REQUEST_TIMEOUT - Time.now.to_i
          sleep_duration = [0, expiry_timeout].max
        else
          @logger.warn { "[#{self.class}/#{__method__}] Retrieved sampling settings are invalid. Ensure proper configuration." }
        end
      rescue JSON::ParserError => e
        @logger.warn { "[#{self.class}/#{__method__}] JSON parsing error: #{e.message}" }
      rescue StandardError => e
        @logger.warn { "[#{self.class}/#{__method__}] Failed to retrieve sampling settings (#{e.message}), tracing will be disabled until valid ones are available." }
      ensure
        sleep(sleep_duration)
      end
    end
  end
end
