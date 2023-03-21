module SolarWindsOTelAPM
  # override the Ruby method, so that no code related to profiling gets executed
  class Profiling
    def self.run
      yield
    end
  end

  # these put the c-functions into "noop"
  module CProfiler
    def self.interval_setup(_); end

    def self.tid
      0
    end
  end
end
