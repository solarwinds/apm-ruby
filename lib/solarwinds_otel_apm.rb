# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

begin
  require 'solarwinds_otel_apm/version'
  require 'solarwinds_otel_apm/thread_local'
  require 'solarwinds_otel_apm/logger'
  require 'solarwinds_otel_apm/util'
  require 'solarwinds_otel_apm/support_report'
  require 'solarwinds_otel_apm/base'
  require 'solarwinds_otel_apm/constants'
  require 'solarwinds_otel_apm/config'
  
  SolarWindsOTelAPM::Config.load_config_file

  SolarWindsOTelAPM.loaded = false
  begin
    if RUBY_PLATFORM =~ /linux/
      require_relative './libsolarwinds_apm.so'
      require 'solarwinds_otel_apm/layerinit'
      require 'solarwinds_otel_apm/oboe_init_options'
      require 'oboe_metal.rb'  # initialize Reporter; sets SolarWindsOTelAPM.loaded = true if successful
    else
      SolarWindsOTelAPM.logger.warn '==================================================================='
      SolarWindsOTelAPM.logger.warn "SolarWindsOTelAPM warning: Platform #{RUBY_PLATFORM} not yet supported."
      SolarWindsOTelAPM.logger.warn 'see: https://documentation.solarwinds.com/en/success_center/observability/default.htm#cshid=config-ruby-agent'
      SolarWindsOTelAPM.logger.warn 'Tracing disabled.'
      SolarWindsOTelAPM.logger.warn 'Contact technicalsupport@solarwinds.com if this is unexpected.'
      SolarWindsOTelAPM.logger.warn '==================================================================='
    end
  rescue LoadError => e
    unless ENV['RAILS_GROUP'] == 'assets' or ENV['SW_APM_NO_LIBRARIES_WARNING']
      SolarWindsOTelAPM.logger.error '=============================================================='
      SolarWindsOTelAPM.logger.error 'Missing SolarWindsOTelAPM libraries.  Tracing disabled.'
      SolarWindsOTelAPM.logger.error "Error: #{e.message}"
      SolarWindsOTelAPM.logger.error 'See: https://documentation.solarwinds.com/en/success_center/observability/default.htm#cshid=config-ruby-agent'
      SolarWindsOTelAPM.logger.error '=============================================================='
    end
  end

  # Auto-start the Reporter unless we are running Unicorn on Heroku
  # In that case, we start the reporters after fork
  unless SolarWindsOTelAPM.heroku? && SolarWindsOTelAPM.forking_webserver?
    SolarWindsOTelAPM::Reporter.start if SolarWindsOTelAPM.loaded
  end
  if SolarWindsOTelAPM.loaded
    require 'solarwinds_otel_apm/load_opentelemetry'
  else
    SolarWindsOTelAPM.logger.warn '=============================================================='
    SolarWindsOTelAPM.logger.warn 'SolarWindsOTelAPM not loaded. Tracing disabled.'
    SolarWindsOTelAPM.logger.warn 'There may be a problem with the service key or other settings.'
    SolarWindsOTelAPM.logger.warn 'Please check previous log messages.'
    SolarWindsOTelAPM.logger.warn '=============================================================='
    require 'solarwinds_otel_apm/noop/context'
    require 'solarwinds_otel_apm/noop/metadata'
  end

  require 'solarwinds_otel_apm/test' if ENV['SW_APM_GEM_TEST']
rescue => e
  $stderr.puts "[solarwinds_otel_apm/error] Problem loading: #{e.inspect}"
  $stderr.puts e.backtrace
end
