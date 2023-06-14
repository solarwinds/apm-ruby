# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

##
# This module is the base module for SolarWindsAPM reporting.
#
module SolarWindsAPMBase
  extend SolarWindsAPM::ThreadLocal

  attr_accessor :reporter, :loaded

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

module SolarWindsAPM
  extend SolarWindsAPMBase
end

# Setup an alias
SolarwindsAPM = SolarWindsAPM
SolarWindsApm = SolarWindsAPM
SolarwindsApm = SolarWindsAPM
SolarwindsApm = SolarWindsAPM
SolarwindsAPM = SolarWindsAPM
