module SolarWindsOTelAPM
  module API
    module Tracing
      # Wait for SolarWinds to be ready to send traces.
      #
      # This may be useful in short lived background processes when it is important to capture
      # information during the whole time the process is running. Usually SolarWinds doesn't block an
      # application while it is starting up.
      #
      # === Argument:
      #
      # * +wait_milliseconds+ (int, default 3000) the maximum time to wait in milliseconds
      #
      # === Example:
      #
      #   unless SolarWindsOTelAPM::API.solarwinds_ready?(10_000)
      #     Logger.info "SolarWindsOTelAPM not ready after 10 seconds, no metrics will be sent"
      #   end
      # 
      # === Returns:
      # * True or False (Boolean)
      #
      def solarwinds_ready?(wait_milliseconds=3000)
        return false unless SolarWindsOTelAPM.loaded && SolarWindsOTelAPM::Context.toString != '00-00000000000000000000000000000000-0000000000000000-00'

        SolarWindsOTelAPM::Context.isReady(wait_milliseconds) == 1
      end
    end
  end
end