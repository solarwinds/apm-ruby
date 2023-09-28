module SolarWindsAPM
  module API
    module Tracing
      # Wait for SolarWinds to be ready to send traces.
      #
      # This may be useful in short lived background processes when it is important to capture
      # information during the whole time the process is running. It returns boolean if <tt>integer_response</tt> is false,
      # and it will return integer if setting <tt>integer_response</tt> as true.
      # Usually SolarWinds doesn't block an application while it is starting up.
      # 
      # For status code reference:
      #   0: unknown error
      #   1: is ready
      #   2: not ready yet, try later
      #   3: limit exceeded
      #   4: invalid API key
      #   5: connection error
      #
      # === Argument:
      #
      # * +wait_milliseconds+ - (int, default 3000) the maximum time to wait in milliseconds
      # * +integer_response+  - (boolean, default false) determine whether return status code of reporter or not
      #
      # === Example:
      #
      #   unless SolarWindsAPM::API.solarwinds_ready?(10_000)
      #     Logger.info "SolarWindsAPM not ready after 10 seconds, no metrics will be sent"
      #   end
      # 
      #   # with status code print out
      #   status = SolarWindsAPM::API.solarwinds_ready?(10_000, integer_response: true)
      #   unless status == 1
      #     Logger.info "SolarWindsAPM not ready after 10 seconds, no metrics will be sent. Error code "#{status}"
      #   end
      # 
      # === Returns:
      # * Boolean (if integer_response: false)
      # * Integer (if integer_response: true)
      #
      def solarwinds_ready?(wait_milliseconds=3000, integer_response: false)
        return false unless SolarWindsAPM.loaded

        is_ready = SolarWindsAPM::Context.isReady(wait_milliseconds)

        return is_ready if integer_response

        is_ready == 1
      end
    end
  end
end