# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require_relative 'logger_formatter'

Lumberjack::Formatter.prepend(SolarWindsAPM::Logger::Formatter) if SolarWindsAPM.loaded && defined?(Lumberjack::Formatter)
