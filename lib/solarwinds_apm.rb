# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

begin  
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
    if RUBY_PLATFORM =~ /linux/
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

  # Auto-start the Reporter unless we are running Unicorn on Heroku
  # In that case, we start the reporters after fork
  unless SolarWindsAPM.forking_webserver?
    SolarWindsAPM::Reporter.start if SolarWindsAPM.loaded
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

  else
    SolarWindsAPM.logger.warn '=============================================================='
    SolarWindsAPM.logger.warn 'SolarWindsAPM not loaded. Tracing disabled.'
    SolarWindsAPM.logger.warn 'There may be a problem with the service key or other settings.'
    SolarWindsAPM.logger.warn 'Please check previous log messages.'
    SolarWindsAPM.logger.warn '=============================================================='
    require 'solarwinds_apm/noop/context'
    require 'solarwinds_apm/noop/metadata'
  end
rescue StandardError => e
  $stderr.puts "[solarwinds_apm/error] Problem loading: #{e.inspect}"
  $stderr.puts e.backtrace
end
