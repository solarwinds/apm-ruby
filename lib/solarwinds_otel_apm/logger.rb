# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'logger'

module SolarWindsOTelAPM
  class << self
    attr_accessor :logger
  end
end

SolarWindsOTelAPM.logger = Logger.new(STDERR)
# set log level to INFO to be consistent with the c-lib, DEBUG would be default
SolarWindsOTelAPM.logger.level = Logger::INFO
