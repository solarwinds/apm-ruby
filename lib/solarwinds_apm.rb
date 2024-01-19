# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

begin
  if ENV.fetch('SW_APM_ENABLED', 'true') == 'false'
    SolarWindsAPM.logger.warn 'SW_APM_ENABLED environment variable detected and was set to false; SolarWindsAPM disabled'
    return
  end

  require 'solarwinds_apm/version'
  require 'solarwinds_apm/thread_local'
  require 'solarwinds_apm/support_report'
  require 'solarwinds_apm/constants'
  require 'solarwinds_apm/api'
  require 'solarwinds_apm/base'
  require 'solarwinds_apm/logger'
  require 'solarwinds_apm/config'

  SolarWindsAPM::Config.load_config_file
  SolarWindsAPM.loaded = false
  begin
    if /linux/.match?(RUBY_PLATFORM)
      require_relative './libsolarwinds_apm.so'
      require 'solarwinds_apm/oboe_init_options'
      require_relative './oboe_metal'  # initialize Reporter; sets SolarWindsAPM.loaded = true if successful
    else
      SolarWindsAPM.logger.warn '==================================================================='
      SolarWindsAPM.logger.warn "SolarWindsAPM warning: Platform #{RUBY_PLATFORM} not yet supported."
      SolarWindsAPM.logger.warn 'see: https://documentation.solarwinds.com/en/success_center/observability/default.htm#cshid=config-ruby-agent'
      SolarWindsAPM.logger.warn 'Tracing disabled.'
      SolarWindsAPM.logger.warn 'Contact technicalsupport@solarwinds.com if this is unexpected.'
      SolarWindsAPM.logger.warn '==================================================================='
    end
  rescue LoadError => e
    unless ENV['RAILS_GROUP'] == 'assets' || ENV['SW_APM_NO_LIBRARIES_WARNING']
      SolarWindsAPM.logger.error '=============================================================='
      SolarWindsAPM.logger.error 'Missing SolarWindsAPM libraries.  Tracing disabled.'
      SolarWindsAPM.logger.error "Error: #{e.message}"
      SolarWindsAPM.logger.error 'See: https://documentation.solarwinds.com/en/success_center/observability/default.htm#cshid=config-ruby-agent'
      SolarWindsAPM.logger.error '=============================================================='
    end
  end

  if SolarWindsAPM.lambda?
    SolarWindsAPM.oboe_api = SolarWindsAPM::OboeAPI.new  # start oboe api for lambda env
    SolarWindsAPM.is_lambda = true
    require 'solarwinds_apm/noop'
  end

  if SolarWindsAPM.loaded
    require 'solarwinds_apm/support'
    require 'solarwinds_apm/opentelemetry'
    require 'solarwinds_apm/otel_config'
    if ENV['SW_APM_AUTO_CONFIGURE'] == 'false'
      SolarWindsAPM.logger.warn "SolarWindsAPM warning: Ruby library is not initilaized.
                                  You may need to initialize Ruby library in application like the following:
                                  SolarWindsAPM::OTelConfig.initialize_with_config do |config|
                                    ...
                                  end"
    else
      SolarWindsAPM::OTelConfig.initialize
    end

    SolarWindsAPM::Reporter.start
  else
    SolarWindsAPM.logger.warn '=============================================================='
    SolarWindsAPM.logger.warn 'SolarWindsAPM not loaded. Tracing disabled.'
    SolarWindsAPM.logger.warn 'There may be a problem with the service key or other settings.'
    SolarWindsAPM.logger.warn 'Please check previous log messages.'
    SolarWindsAPM.logger.warn '=============================================================='
    require 'solarwinds_apm/noop'
  end
rescue StandardError => e
  $stderr.puts "[solarwinds_apm/error] Problem loading: #{e.inspect}"
  $stderr.puts e.backtrace
end
