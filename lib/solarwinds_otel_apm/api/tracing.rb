module SolarWindsOTelAPM
	module API
    module Tracing
      def solarwinds_ready?(wait_milliseconds = 3000)
        return false unless SolarWindsOTelAPM.loaded
        # These codes are returned by isReady:
        # OBOE_SERVER_RESPONSE_UNKNOWN 0
        # OBOE_SERVER_RESPONSE_OK 1
        # OBOE_SERVER_RESPONSE_TRY_LATER 2
        # OBOE_SERVER_RESPONSE_LIMIT_EXCEEDED 3
        # OBOE_SERVER_RESPONSE_INVALID_API_KEY 4
        # OBOE_SERVER_RESPONSE_CONNECT_ERROR 5
        SolarWindsOTelAPM::Context.isReady(wait_milliseconds) == 1
      end
    end
  end
end