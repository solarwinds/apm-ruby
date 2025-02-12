# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

class HttpSampler < Sampler
  REQUEST_TIMEOUT = 10 * 1000 # 10s
  RETRY_INITIAL_TIMEOUT = 500 # 500ms
  RETRY_MAX_TIMEOUT = 60 * 1000 # 60s
  RETRY_MAX_ATTEMPTS = 20
  MULTIPLIER = 1.5

  # we don't need hostname as it's for separating browser and local env
  def initialize(config)
    super(config, SolarWindsAPM.logger)

    @url = config[:collector]
    @service = URI.encode_www_form_component(config[:service]) # service name "Hello world" -> "Hello%20world"
    @headers = config[:headers]

    @hostname = hostname
    @setting_url = URI.join(@url, "./v1/settings/#{@service}/#{@hostname}")

    @retry = 0
    @retry_timeout = RETRY_INITIAL_TIMEOUT

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
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
        request = Net::HTTP::Get.new(uri)
        request['Authorization'] = @headers

        response = http.request(request)
      end
    rescue StandardError => e
      @logger.debug { "Error during request: #{e.message}" }
    end

    begin
      Timeout.timeout(timeout_seconds || REQUEST_TIMEOUT) do
        thread.join
      end
    rescue Timeout::Error
      @logger.debug { "Request timed out after #{timeout_seconds} seconds" }
      thread.kill
    end

    response
  end

  def reset_retry
    @retry = 0
    @retry_timeout = RETRY_INITIAL_TIMEOUT
  end

  def retry_request
    @retry += 1
    @retry_timeout *= MULTIPLIER
    should_timeout = @retry < RETRY_MAX_ATTEMPTS && @retry_timeout < RETRY_MAX_TIMEOUT

    if should_timeout
      @logger.debug { "Retrying in #{(@retry_timeout / 1000.0).round(1)}s" }
      sleep(@retry_timeout / 1000.0)
      settings_request(timeout = @retry_timeout)
    else
      @logger.warn { 'Reached max retry attempts for sampling settings retrieval. Tracing will remain disabled.' }
    end
  end

  # a endless loop within a thread (non-blocking)
  # it won't affect then call HttpSampler.should_sample (since it only update bucket settings)
  def settings_request(timeout = nil)
    
    @logger.debug { "Retrieving sampling settings from #{@setting_url}" }

    response = fetch_with_timeout(@setting_url)
    parsed = JSON.parse(response.body)

    @logger.debug { "parsed settings in json: #{parsed.inspect}" }

    unless update_settings(parsed)
      @logger.warn { 'Retrieved sampling settings are invalid. Ensure proper configuration.' }
      retry_request
    end

    reset_retry

    # this is pretty arbitrary but the goal is to update the settings
    # before the previous ones expire with some time to spare
    expiry = (parsed['timestamp'] + parsed['ttl']) * 1000
    timeout = expiry - (REQUEST_TIMEOUT * MULTIPLIER) - (Time.now.to_i * 1000)
    sleep([0, timeout / 1000.0].max)
    settings_request
  rescue StandardError => e
    @logger.warn { "Failed to retrieve sampling settings (#{e.message}), tracing will be disabled until valid ones are available." }
    retry_request
  end
end
