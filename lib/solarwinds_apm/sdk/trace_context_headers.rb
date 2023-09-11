#sh Copyright (c) SolarWinds, LLC.
# All rights reserved.

module SolarWindsAPM
  module SDK
    ##
    #
    # Module to be included in classes with outbound calls
    #
    module TraceContextHeaders
      REGEXP = /^(?<tracestring>(?<version>[a-f0-9]{2})-(?<trace_id>[a-f0-9]{32})-(?<span_id>[a-f0-9]{16})-(?<flags>[a-f0-9]{2}))$/
      private_constant :REGEXP
      ##
      # Add w3c tracecontext to headers arg
      #
      # === Argument:
      # * +:headers+   outbound headers, a Hash or other object that can have key/value assigned
      #
      # Internally it uses SolarWindsAPM.trace_context, which is a thread local
      # variable containing verified and processed incoming w3c headers.
      # It gets populated by requests processed by Rack or through the
      # :headers arg in SolarWindsAPM::SDK.start_trace
      #
      # === Example:
      # class OutboundCaller
      #   include SolarWindsAPM::SDK::TraceContextHeaders
      #
      #   # create new headers
      #   def faraday_send
      #     conn = Faraday.new(:url => 'http://example.com')
      #     headers = add_tracecontext_headers
      #     conn.get('/', nil, headers)
      #   end
      #
      #   # add to given headers
      #   def excon_send(headers)
      #     conn = Excon.new('http://example.com')
      #     add_tracecontext_headers(headers)
      #     conn.get(headers: headers)
      #   end
      # end
      #
      # === Returns:
      # * The headers with w3c tracecontext added, also modifies the headers arg if given
      #
      def add_tracecontext_headers(_headers={})
        SolarWindsAPM.logger.warn do
          "SolarWindsAPM::SDK::TraceContextHeaders is depreciated.
                                    You don't need to add_tracecontext_headers to add traceparent and tracestate to headers.
                                    Please refer to TraceContext propagator from opentelemetry ruby"
        end
      end
    end
  end
end
