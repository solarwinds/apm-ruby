# solarwinds_nh will use liboboe to export data to solarwinds swo

module SolarWindsOTelAPM
  module OpenTelemetry
  	class SolarWindsExporter


  		SUCCESS = ::OpenTelemetry::SDK::Trace::Export::SUCCESS # ::OpenTelemetry  #=> the OpenTelemetry at top level (to ignore SolarWindsOTelAPM)
  		FAILURE = ::OpenTelemetry::SDK::Trace::Export::FAILURE
  		private_constant(:SUCCESS, :FAILURE)
  	
  		def initialize(endpoint: ENV['SW_APM_EXPORTER'],
  		               # username: ENV['OTEL_EXPORTER_JAEGER_USER'],
  		               # password: ENV['OTEL_EXPORTER_JAEGER_PASSWORD'],
  		               # timeout: ENV.fetch('OTEL_EXPORTER_JAEGER_TIMEOUT', 10),
  		               # ssl_verify_mode: CollectorExporter.ssl_verify_mode,
  		               metrics_reporter: nil,
  		               service_key: ENV['SW_APM_SERVICE_KEY']
  		               )
  		  raise ArgumentError, "Missing SW_APM_SERVICE_KEY." if service_key.nil?
  		  
  		  @metrics_reporter = metrics_reporter || ::OpenTelemetry::SDK::Trace::Export::MetricsReporter
  		  @shutdown = false
  		end

  		def export(span_data, timeout: nil)
  			return FAILURE if @shutdown
  			puts "span_data: #{span_data.inspect}"
  			# span_data = SolarWindsOTelAPM::OpenTelemetry::Transformer.transform(span_data)
  			
  			SolarWindsOTelAPM::API.log_entry('layer', span_data)
  			# SolarWindsOTelAPM::API.log_exception('layer', span_data)
  			# SolarWindsOTelAPM::API.log_exit('layer', span_data)

  		end

  		def force_flush(timeout: nil)
  		  SUCCESS
  		end

  		def shutdown(timeout: nil)
  		  @shutdown = true
  		  SUCCESS
  		end

  		private

  		def encoded_batches(span_data)
        span_data.group_by(&:resource).map do |resource, spans|
          process = Encoder.encoded_process(resource)
          spans.map! { |span| Encoder.encoded_span(span) }
          Thrift::Batch.new('process' => process, 'spans' => spans)
        end
      end

      def measure_request_duration
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        yield
      ensure
        stop = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        duration_ms = 1000.0 * (stop - start)
        @metrics_reporter.record_value('solarwinds_apm.request_duration', value: duration_ms)
      end

  	end
  end
end



