module SolarWindsAPM
  module API
    module OpenTelemetry
      # Create custom span based on current last span
      #
      # Wrap OpenTelemetry function OpenTelemetry.tracer_provider.tracer.in_span
      #
      # === Argument:
      #
      # * +name+ - (int, default 3000) the maximum time to wait in milliseconds
      # * +attributes+ - (hash, default nil)
      # * +links+ - (string, default nil)
      # * +start_timestamp+ - (int, default nil)
      # * +kind+ - (symbol, default nil)
      #
      # === Example:
      #
      #   SolarWindsAPM::API.in_span('custom_span') do |span|
      #     url = URI.parse("http://www.google.ca/")
      #     req = Net::HTTP::Get.new(url.to_s)
      #     res = Net::HTTP.start(url.host, url.port) {|http| http.request(req)}
      #   end
      # 
      # === Returns:
      # * Objective
      #
      def in_span(name, attributes: nil, links: nil, start_timestamp: nil, kind: nil, &block)
        if block.nil?
          SolarWindsAPM.logger.warn {"[#{name}/#{__method__}] please provide block when using in_span function"}
          return
        end

        SolarWindsAPM.logger.debug {"[#{name}/#{__method__}] solarwinds_apm in_span with OTEL_SERVICE_NAME #{ENV['OTEL_SERVICE_NAME']}"}
        current_tracer = ::OpenTelemetry.tracer_provider.tracer(ENV['OTEL_SERVICE_NAME'])
        current_tracer.in_span(name, attributes: attributes, links: links, start_timestamp: start_timestamp, kind: kind, &block)
      end
    end
  end
end