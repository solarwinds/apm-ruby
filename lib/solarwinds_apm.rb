# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

begin
  require 'solarwinds_apm/logger'
  require 'solarwinds_apm/version'
  require 'opentelemetry-api'
  if ENV.fetch('SW_APM_ENABLED', 'true') == 'false'
    SolarWindsAPM.logger.info '==================================================================='
    SolarWindsAPM.logger.info 'SW_APM_ENABLED environment variable detected and was set to false. SolarWindsAPM disabled'
    SolarWindsAPM.logger.info '==================================================================='
    require 'solarwinds_apm/noop'
    return
  end

  begin
    if /linux/.match?(RUBY_PLATFORM)
      require 'solarwinds_apm/config'
      SolarWindsAPM::Config.load_config_file

      require 'solarwinds_apm/oboe_init_options'      # setup oboe reporter options
      unless SolarWindsAPM::OboeInitOptions.instance.service_key_ok?
        SolarWindsAPM.logger.warn '=============================================================='
        SolarWindsAPM.logger.warn 'SW_APM_SERVICE_KEY Error. SolarWinds APM disabled'
        SolarWindsAPM.logger.warn 'Please check previous log messages for more details.'
        SolarWindsAPM.logger.warn '=============================================================='
        require 'solarwinds_apm/noop'
        return
      end

      require_relative './libsolarwinds_apm.so'       # load c-lib oboe
      require_relative './oboe_metal'                 # initialize reporter: SolarWindsAPM.loaded = true

      require 'opentelemetry/sdk/version'                 # load otel sdk version
      require 'opentelemetry/instrumentation/all/version' # load otel instrumentation

      SolarWindsAPM.logger.info '==================================================================='
      SolarWindsAPM.logger.info "Ruby #{RUBY_VERSION} on platform #{RUBY_PLATFORM}."
      SolarWindsAPM.logger.info "Current solarwinds_apm version: #{SolarWindsAPM::Version::STRING}."
      SolarWindsAPM.logger.info "OpenTelemetry version: #{OpenTelemetry::SDK::VERSION}."
      SolarWindsAPM.logger.info "OpenTelemetry instrumentation version: #{OpenTelemetry::Instrumentation::All::VERSION}."
      SolarWindsAPM.logger.info '==================================================================='

      SolarWindsAPM::Reporter.start                 # start the reporter, any issue will be logged

      if SolarWindsAPM.loaded
        require 'solarwinds_apm/constants'
        require 'solarwinds_apm/api'
        require 'solarwinds_apm/support'
        require 'solarwinds_apm/opentelemetry'
        require 'solarwinds_apm/patch'
        require 'solarwinds_apm/otel_config'
        
        if ENV['SW_APM_AUTO_CONFIGURE'] != 'false'
          SolarWindsAPM::OTelConfig.initialize
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
      else
        SolarWindsAPM.logger.warn '=============================================================='
        SolarWindsAPM.logger.warn 'SolarWindsAPM not loaded. SolarWinds APM disabled'
        SolarWindsAPM.logger.warn 'Please check previous log messages.'
        SolarWindsAPM.logger.warn '=============================================================='
        require 'solarwinds_apm/noop'
      end
    else
      SolarWindsAPM.logger.warn '==================================================================='
      SolarWindsAPM.logger.warn "SolarWindsAPM warning: Platform #{RUBY_PLATFORM} not yet supported on current solarwinds_apm #{SolarWindsAPM::Version::STRING}"
      SolarWindsAPM.logger.warn 'see: https://documentation.solarwinds.com/en/success_center/observability/default.htm#cshid=config-ruby-agent'
      SolarWindsAPM.logger.warn 'SolarWinds APM disabled.'
      SolarWindsAPM.logger.warn 'Contact technicalsupport@solarwinds.com if this is unexpected.'
      SolarWindsAPM.logger.warn '==================================================================='
      require 'solarwinds_apm/noop'
    end
  rescue LoadError => e
    SolarWindsAPM.logger.error '=============================================================='
    SolarWindsAPM.logger.error 'Error occurs while loading solarwinds_apm. SolarWinds APM disabled.'
    SolarWindsAPM.logger.error "Error: #{e.message}"
    SolarWindsAPM.logger.error 'See: https://documentation.solarwinds.com/en/success_center/observability/default.htm#cshid=config-ruby-agent'
    SolarWindsAPM.logger.error '=============================================================='
    require 'solarwinds_apm/noop'
  end
  
rescue StandardError => e
  $stderr.puts "[solarwinds_apm/error] Problem loading: #{e.inspect}"
  $stderr.puts e.backtrace
  require 'solarwinds_apm/noop'
end
