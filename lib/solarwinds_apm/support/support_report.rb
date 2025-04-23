# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'rbconfig'
require 'logger'

##
# This module is used to debug problematic setups and/or environments.
# Depending on the environment, output may be to stdout or the framework
# log file (e.g. log/production.log)
module SolarWindsAPM
  ##
  # yesno
  #
  # Utility method to translate value/nil to "yes"/"no" strings
  def self.yesno(condition)
    condition ? 'yes' : 'no'
  end

  def self.support_report
    @logger_level = SolarWindsAPM.logger.level
    SolarWindsAPM.logger.level = ::Logger::DEBUG

    SolarWindsAPM.logger.warn '********************************************************'
    SolarWindsAPM.logger.warn '* BEGIN SolarWindsAPM Support Report'
    SolarWindsAPM.logger.warn '*   Please email the output of this report to SWO-support@solarwinds.com'
    SolarWindsAPM.logger.warn '********************************************************'
    SolarWindsAPM.logger.warn "Ruby: #{RUBY_DESCRIPTION}"
    SolarWindsAPM.logger.warn "PROGRAM_NAME: #{$PROGRAM_NAME}" # replace $0 to get executing script
    SolarWindsAPM.logger.warn "ARGV: #{ARGV.inspect}"

    SolarWindsAPM.logger.warn "SolarWindsAPM::Ruby defined?: #{yesno(defined?(SolarWindsAPM::Ruby))}"
    SolarWindsAPM.logger.warn "SolarWindsAPM.reporter: #{SolarWindsAPM.reporter}"

    SolarWindsAPM.logger.warn '********************************************************'
    SolarWindsAPM.logger.warn '* Frameworks'
    SolarWindsAPM.logger.warn '********************************************************'

    using_rails = defined?(::Rails)
    SolarWindsAPM.logger.warn "Using Rails?: #{yesno(using_rails)}"
    if using_rails
      SolarWindsAPM.logger.warn "SolarWindsAPM::Rails loaded?: #{yesno(defined?(SolarWindsAPM::Rails))}"
      SolarWindsAPM.logger.warn "SolarWindsAPM::Rack middleware loaded?: #{yesno(::Rails.configuration.middleware.include?(SolarWindsAPM::Rack))}" if defined?(SolarWindsAPM::Rack)
    end

    using_sinatra = defined?(::Sinatra)
    SolarWindsAPM.logger.warn "Using Sinatra?: #{yesno(using_sinatra)}"

    using_padrino = defined?(::Padrino)
    SolarWindsAPM.logger.warn "Using Padrino?: #{yesno(using_padrino)}"

    using_grape = defined?(::Grape)
    SolarWindsAPM.logger.warn "Using Grape?: #{yesno(using_grape)}"

    SolarWindsAPM.logger.warn '********************************************************'
    SolarWindsAPM.logger.warn '* ActiveRecord Adapter'
    SolarWindsAPM.logger.warn '********************************************************'
    if defined?(::ActiveRecord)
      if defined?(::ActiveRecord::Base.connection.adapter_name)
        SolarWindsAPM.logger.warn "ActiveRecord adapter: #{::ActiveRecord::Base.connection.adapter_name}"
      end
    else
      SolarWindsAPM.logger.warn 'No ActiveRecord'
    end

    SolarWindsAPM.logger.warn '********************************************************'
    SolarWindsAPM.logger.warn '* SolarWindsAPM::Config Values'
    SolarWindsAPM.logger.warn '********************************************************'
    SolarWindsAPM.logger.warn SolarWindsAPM::Config.print_config.to_s

    SolarWindsAPM.logger.warn '********************************************************'
    SolarWindsAPM.logger.warn '* SolarWindsAPM::OTelConfig Values'
    SolarWindsAPM.logger.warn '********************************************************'
    SolarWindsAPM.logger.warn SolarWindsAPM::OTelConfig.print_config.to_s

    SolarWindsAPM.logger.warn '********************************************************'
    SolarWindsAPM.logger.warn '* OS, Platform + Env'
    SolarWindsAPM.logger.warn '********************************************************'
    SolarWindsAPM.logger.warn "host_os:  #{RbConfig::CONFIG['host_os']}"
    SolarWindsAPM.logger.warn "sitearch: #{RbConfig::CONFIG['sitearch']}"
    SolarWindsAPM.logger.warn "arch:     #{RbConfig::CONFIG['arch']}"
    SolarWindsAPM.logger.warn "Platform: #{RUBY_PLATFORM}"

    SolarWindsAPM.logger.warn '********************************************************'
    SolarWindsAPM.logger.warn '* END SolarWindsAPM Support Report'
    SolarWindsAPM.logger.warn '*   Support Email: technicalsupport@solarwinds.com'
    SolarWindsAPM.logger.warn '*   Github: https://github.com/solarwinds/apm-ruby'
    SolarWindsAPM.logger.warn '********************************************************'

    SolarWindsAPM.logger.level = @logger_level
    nil
  end
end
