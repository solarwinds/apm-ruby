# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

begin
  require 'solarwinds_apm/logger'
  require 'solarwinds_apm/version'
  require 'solarwinds_apm/constants'
  require 'solarwinds_apm/noop'
  require 'opentelemetry-api'
  if ENV.fetch('SW_APM_ENABLED', 'true') == 'false'
    SolarWindsAPM.logger.info '==================================================================='
    SolarWindsAPM.logger.info 'SW_APM_ENABLED environment variable detected and was set to false. SolarWindsAPM disabled'
    SolarWindsAPM.logger.info '==================================================================='
    return
  end

  begin
    require 'solarwinds_apm/config'
    require 'solarwinds_apm/otel_native_config'

    if ENV['SW_APM_AUTO_CONFIGURE'] != 'false'
      SolarWindsAPM::OTelNativeConfig.initialize
      if SolarWindsAPM::OTelNativeConfig.agent_enabled
        SolarWindsAPM.logger.info '==================================================================='
        SolarWindsAPM.logger.info "Ruby #{RUBY_VERSION} on platform #{RUBY_PLATFORM}."
        SolarWindsAPM.logger.info "Current solarwinds_apm version: #{SolarWindsAPM::Version::STRING}."
        SolarWindsAPM.logger.info "OpenTelemetry version: #{OpenTelemetry::SDK::VERSION}."
        SolarWindsAPM.logger.info "OpenTelemetry instrumentation version: #{OpenTelemetry::Instrumentation::All::VERSION}."
        SolarWindsAPM.logger.info '==================================================================='
      else
        SolarWindsAPM.logger.warn '=============================================================='
        SolarWindsAPM.logger.warn 'SolarWindsAPM not loaded. SolarWinds APM disabled'
        SolarWindsAPM.logger.warn 'Please check previous log messages.'
        SolarWindsAPM.logger.warn '=============================================================='
      end

    elsif ENV['SW_APM_AUTO_CONFIGURE'] == 'false'
      SolarWindsAPM.logger.warn '=============================================================='
      SolarWindsAPM.logger.warn 'SW_APM_AUTO_CONFIGURE set to false.'
      SolarWindsAPM.logger.warn 'You need to initialize Ruby library in application with'
      SolarWindsAPM.logger.warn 'SolarWindsAPM::OTelConfig.initialize_with_config do |config|'
      SolarWindsAPM.logger.warn '  # ... your configuration code'
      SolarWindsAPM.logger.warn 'end'
      SolarWindsAPM.logger.warn 'See: https://github.com/solarwinds/apm-ruby/blob/main/CONFIGURATION.md#in-code-configuration'
      SolarWindsAPM.logger.warn "\e[1mPlease discard this message if application have already taken this action.\e[0m"
      SolarWindsAPM.logger.warn '=============================================================='
    end
  end
rescue StandardError => e
  warn "[solarwinds_apm/error] Problem loading: #{e.inspect}"
  warn e.backtrace
end
