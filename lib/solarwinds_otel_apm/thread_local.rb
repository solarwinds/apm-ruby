# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsOTelAPM
  ##
  # Provides thread local storage for SolarWindsOTelAPM.
  #
  # Example usage:
  # module SolarWindsOTelAPMBase
  #   extend SolarWindsOTelAPM::ThreadLocal
  #   thread_local :layer_op
  # end
  module ThreadLocal
    def thread_local(name)
      key = "__#{self}_#{name}__".intern

      define_method(name) do
        Thread.current[key]
      end

      define_method("#{name}=") do |value|
        Thread.current[key] = value
      end
    end
  end
end
