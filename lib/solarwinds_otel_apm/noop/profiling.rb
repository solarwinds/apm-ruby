module SolarWindsOTelAPM
  # override the Ruby method, so that no code related to profiling gets executed
  class Profiling
    def self.run
      yield
    end
  end

  # these put the c-functions into "noop"
  module CProfiler
    def self.set_interval(_); end

    def self.get_tid
      0
    end
  end
end
