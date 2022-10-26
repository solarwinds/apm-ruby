# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

begin
  require 'openssl'
  require 'solarwinds_otel_apm/version'
  require 'solarwinds_otel_apm/logger'
  require 'solarwinds_otel_apm/util'
  require 'solarwinds_otel_apm/support_report'
  require 'solarwinds_otel_apm/base'
  SolarWindsOTelAPM.loaded = false

  require 'solarwinds_otel_apm/config'
  SolarWindsOTelAPM::Config.load_config_file

  begin
    if RUBY_PLATFORM =~ /linux/
      require_relative './libsolarwinds_apm.so'
      require 'solarwinds_otel_apm/oboe_init_options'
      require 'oboe_metal.rb'  # sets SolarWindsOTelAPM.loaded = true if successful
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

  # solarwinds_otel_apm/loading can set SolarWindsOTelAPM.loaded = false if the service key is not working
  require 'solarwinds_otel_apm/loading'

  if SolarWindsOTelAPM.loaded

    require 'opentelemetry/sdk'
    require 'opentelemetry/exporter/otlp'
    require 'opentelemetry/instrumentation/all'

    # override
    require_relative './configurator.rb'
    require 'solarwinds_otel_apm/opentelemetry/solarwinds_exporter'

    if defined?(OpenTelemetry::SDK::Configurator)
      OpenTelemetry::SDK.configure do |c|
        c.service_name = ENV['SERVICE_NAME'] || ""
        c.use_all() # enables all instrumentation! or use logic to determine which module to require
      end
    end
    
  else
    SolarWindsOTelAPM.logger.warn '=============================================================='
    SolarWindsOTelAPM.logger.warn 'SolarWindsOTelAPM not loaded. Tracing disabled.'
    SolarWindsOTelAPM.logger.warn 'There may be a problem with the service key or other settings.'
    SolarWindsOTelAPM.logger.warn 'Please check previous log messages.'
    SolarWindsOTelAPM.logger.warn '=============================================================='
    require 'solarwinds_otel_apm/noop/context'
    require 'solarwinds_otel_apm/noop/metadata'
  end

  

  # Load Ruby module last.  If there is no framework detected,
  # it will load all of the Ruby instrumentation
  require 'solarwinds_otel_apm/ruby'

  require 'solarwinds_otel_apm/test' if ENV['SW_APM_GEM_TEST']
rescue => e
  $stderr.puts "[solarwinds_otel_apm/error] Problem loading: #{e.inspect}"
  $stderr.puts e.backtrace
end
