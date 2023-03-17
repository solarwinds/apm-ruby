# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'rbconfig'
require 'logger'

module SolarWindsOTelAPM
  ##
  # This module is used to debug problematic setups and/or environments.
  # Depending on the environment, output may be to stdout or the framework
  # log file (e.g. log/production.log)

  ##
  # yesno
  #
  # Utility method to translate value/nil to "yes"/"no" strings
  def self.yesno(x)
    x ? 'yes' : 'no'
  end

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize
  def self.support_report
    @logger_level = SolarWindsOTelAPM.logger.level
    SolarWindsOTelAPM.logger.level = ::Logger::DEBUG

    SolarWindsOTelAPM.logger.warn '********************************************************'
    SolarWindsOTelAPM.logger.warn '* BEGIN SolarWindsOTelAPM Support Report'
    SolarWindsOTelAPM.logger.warn '*   Please email the output of this report to technicalsupport@solarwinds.com'
    SolarWindsOTelAPM.logger.warn '********************************************************'
    SolarWindsOTelAPM.logger.warn "Ruby: #{RUBY_DESCRIPTION}"
    SolarWindsOTelAPM.logger.warn "PROGRAM_NAME: #{$PROGRAM_NAME}"   # replace $0 to get executing script
    SolarWindsOTelAPM.logger.warn "ARGV: #{ARGV.inspect}" 
    SolarWindsOTelAPM.logger.warn "SolarWindsOTelAPM.loaded == #{SolarWindsOTelAPM.loaded}"

    on_heroku = SolarWindsOTelAPM.heroku?
    SolarWindsOTelAPM.logger.warn "On Heroku?: #{yesno(on_heroku)}"
    if on_heroku
      SolarWindsOTelAPM.logger.warn "SW_APM_URL: #{ENV['SW_APM_URL']}"
    end

    SolarWindsOTelAPM.logger.warn "SolarWindsOTelAPM::Ruby defined?: #{yesno(defined?(SolarWindsOTelAPM::Ruby))}"
    SolarWindsOTelAPM.logger.warn "SolarWindsOTelAPM.reporter: #{SolarWindsOTelAPM.reporter}"

    SolarWindsOTelAPM.logger.warn '********************************************************'
    SolarWindsOTelAPM.logger.warn '* Frameworks'
    SolarWindsOTelAPM.logger.warn '********************************************************'

    using_rails = defined?(::Rails)
    SolarWindsOTelAPM.logger.warn "Using Rails?: #{yesno(using_rails)}"
    if using_rails
      SolarWindsOTelAPM.logger.warn "SolarWindsOTelAPM::Rails loaded?: #{yesno(defined?(SolarWindsOTelAPM::Rails))}"
      if defined?(SolarWindsOTelAPM::Rack)
        SolarWindsOTelAPM.logger.warn "SolarWindsOTelAPM::Rack middleware loaded?: #{yesno(::Rails.configuration.middleware.include?(SolarWindsOTelAPM::Rack))}"
      end
    end

    using_sinatra = defined?(::Sinatra)
    SolarWindsOTelAPM.logger.warn "Using Sinatra?: #{yesno(using_sinatra)}"

    using_padrino = defined?(::Padrino)
    SolarWindsOTelAPM.logger.warn "Using Padrino?: #{yesno(using_padrino)}"

    using_grape = defined?(::Grape)
    SolarWindsOTelAPM.logger.warn "Using Grape?: #{yesno(using_grape)}"

    SolarWindsOTelAPM.logger.warn '********************************************************'
    SolarWindsOTelAPM.logger.warn '* ActiveRecord Adapter'
    SolarWindsOTelAPM.logger.warn '********************************************************'
    if defined?(::ActiveRecord)
      if defined?(::ActiveRecord::Base.connection.adapter_name)
        SolarWindsOTelAPM.logger.warn "ActiveRecord adapter: #{::ActiveRecord::Base.connection.adapter_name}"
      end
    else
      SolarWindsOTelAPM.logger.warn 'No ActiveRecord'
    end

    SolarWindsOTelAPM.logger.warn '********************************************************'
    SolarWindsOTelAPM.logger.warn '* SolarWindsOTelAPM::Config Values'
    SolarWindsOTelAPM.logger.warn '********************************************************'

    SolarWindsOTelAPM.logger.warn '********************************************************'
    SolarWindsOTelAPM.logger.warn '* OS, Platform + Env'
    SolarWindsOTelAPM.logger.warn '********************************************************'
    SolarWindsOTelAPM.logger.warn "host_os: " + RbConfig::CONFIG['host_os']
    SolarWindsOTelAPM.logger.warn "sitearch: " + RbConfig::CONFIG['sitearch']
    SolarWindsOTelAPM.logger.warn "arch: " + RbConfig::CONFIG['arch']
    SolarWindsOTelAPM.logger.warn RUBY_PLATFORM
    SolarWindsOTelAPM.logger.warn "RACK_ENV: #{ENV['RACK_ENV']}"
    SolarWindsOTelAPM.logger.warn "RAILS_ENV: #{ENV['RAILS_ENV']}" if using_rails

    SolarWindsOTelAPM.logger.warn '********************************************************'
    SolarWindsOTelAPM.logger.warn '* Raw __Init KVs'
    SolarWindsOTelAPM.logger.warn '********************************************************'
    platform_info = SolarWindsOTelAPM::Util.build_swo_init_report
    platform_info.each { |k,v|
      SolarWindsOTelAPM.logger.warn "#{k}: #{v}"
    }

    SolarWindsOTelAPM.logger.warn '********************************************************'
    SolarWindsOTelAPM.logger.warn '* END SolarWindsOTelAPM Support Report'
    SolarWindsOTelAPM.logger.warn '*   Support Email: technicalsupport@solarwinds.com'
    SolarWindsOTelAPM.logger.warn '*   Github: https://github.com/librato/ruby-solarwinds'
    SolarWindsOTelAPM.logger.warn '********************************************************'

    SolarWindsOTelAPM.logger.level = @logger_level
    nil
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize
end
