# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

##
# This module is the base module for SolarWindsOTelAPM reporting.
#
module SolarWindsOTelAPMBase
  extend SolarWindsOTelAPM::ThreadLocal

  attr_accessor :reporter
  attr_accessor :loaded

  ##
  # Determines if we are running under a forking webserver
  #
  def forking_webserver?
    if (defined?(::Unicorn) && ($PROGRAM_NAME =~ /unicorn/i)) ||
       (defined?(::Puma) && ($PROGRAM_NAME =~ /puma/i))
      true
    else
      false
    end
  end
end

module SolarWindsOTelAPM
  extend SolarWindsOTelAPMBase
end

# Setup an alias
SolarwindsOTelAPM = SolarWindsOTelAPM
SolarWindsOtelApm = SolarWindsOTelAPM
SolarwindsotelApm = SolarWindsOTelAPM
SolarwindsOTELApm = SolarWindsOTelAPM
SolarwindsOTELAPM = SolarWindsOTelAPM
