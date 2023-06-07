module SolarWindsOTelAPM
  module API
    module Tracing
      # Public: determine if the agent is ready
      #   These codes are returned by isReady:
      #     OBOE_SERVER_RESPONSE_UNKNOWN 0
      #     OBOE_SERVER_RESPONSE_OK 1
      #     OBOE_SERVER_RESPONSE_TRY_LATER 2
      #     OBOE_SERVER_RESPONSE_LIMIT_EXCEEDED 3
      #     OBOE_SERVER_RESPONSE_CONNECT_ERROR 5
      #
      # Examples
      #
      #   SolarWindsOTelAPM.solarwinds_ready?(10_000)
      #   # => true
      #
      # Parameters:
      #   wait_milliseconds - The time to wait in milliseconds (Integer)
      #
      # Returns:
      #   True or False (Boolean)
      #
      def solarwinds_ready?(wait_milliseconds=3000)
        return false unless SolarWindsOTelAPM.loaded && SolarWindsOTelAPM::Context.toString != '00-00000000000000000000000000000000-0000000000000000-00'

        SolarWindsOTelAPM::Context.isReady(wait_milliseconds) == 1
      end
    end
  end
end