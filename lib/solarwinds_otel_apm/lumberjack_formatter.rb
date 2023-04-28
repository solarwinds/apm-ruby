# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require_relative 'logger_formatter'

Lumberjack::Formatter.prepend(SolarWindsOTelAPM::Logger::Formatter) if SolarWindsOTelAPM.loaded && defined?(Lumberjack::Formatter)
