# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'singleton'
require 'uri'

require_relative './support/service_key_checker'

module SolarWindsAPM
  # OboeInitOptions
  class OboeInitOptions
    include Singleton

    attr_reader :reporter, :host, :service_name, :ec2_md_timeout, :grpc_proxy # exposing these mainly for testing

    def initialize
      # optional hostname alias
      @hostname_alias = ENV['SW_APM_HOSTNAME_ALIAS'] || SolarWindsAPM::Config[:hostname_alias] || ''
      # level at which log messages will be written to log file (0-6)
      @debug_level = (ENV['SW_APM_DEBUG_LEVEL'] || SolarWindsAPM::Config[:debug_level] || 3).to_i
      # file name including path for log file
      # TODO eventually find better way to combine ruby and oboe logs
      @log_file_path = ENV['SW_APM_LOG_FILEPATH'] || ''
      # maximum number of transaction names to track
      @max_transactions = (ENV['SW_APM_MAX_TRANSACTIONS'] || -1).to_i
      # maximum wait time for flushing data before terminating in milli seconds
      @max_flush_wait_time = (ENV['SW_APM_FLUSH_MAX_WAIT_TIME'] || -1).to_i
      # events flush timeout in seconds (threshold for batching messages before sending off)
      @events_flush_interval = (ENV['SW_APM_EVENTS_FLUSH_INTERVAL'] || -1).to_i
      # events flush batch size in KB (threshold for batching messages before sending off)
      @event_flush_batch_size = (ENV['SW_APM_EVENTS_FLUSH_BATCH_SIZE'] || -1).to_i

      # the reporter to be used (ssl, upd, file, null)
      # collector endpoint (reporter=ssl), udp address (reporter=udp), or file path (reporter=file)
      @reporter, @host = reporter_and_host

      # the service key
      @service_key = read_and_validate_service_key
      # certificate content
      @certificates = read_certificates
      # size of the message buffer
      @buffer_size = (ENV['SW_APM_BUFSIZE'] || -1).to_i
      # flag indicating if trace metrics reporting should be enabled (default) or disabled
      @trace_metrics = (ENV['SW_APM_TRACE_METRICS'] || -1).to_i
      # the histogram precision (only for ssl)
      @histogram_precision = (ENV['SW_APM_HISTOGRAM_PRECISION'] || -1).to_i
      # custom token bucket capacity
      @token_bucket_capacity = (ENV['SW_APM_TOKEN_BUCKET_CAPACITY'] || -1).to_i
      # custom token bucket rate
      @token_bucket_rate = (ENV['SW_APM_TOKEN_BUCKET_RATE'] || -1).to_i
      # use single files in file reporter for each event
      @file_single = ENV['SW_APM_REPORTER_FILE_SINGLE'].to_s.casecmp('true').zero? ? 1 : 0
      # timeout for ec2 metadata
      @ec2_md_timeout = read_and_validate_ec2_md_timeout
      @grpc_proxy = read_and_validate_proxy
      # hardcoded arg for lambda (lambda not supported yet)
      # hardcoded arg for grpc hack
      # hardcoded arg for trace id format to use w3c format
      # flag for format of metric (0 = Both; 1 = AppOptics only; 2 = SWO only; default = 0)
      @metric_format = determine_the_metric_model
      # log type (0 = stderr; 1 = stdout; 2 = file; 3 = null; 4 = disabled; default = 0)
      @log_type = determine_oboe_log_type
    end

    # for testing with changed ENV vars
    def re_init
      initialize
    end

    def array_for_oboe
      [
        @hostname_alias,         # 0
        @debug_level,            # 1
        @log_file_path,          # 2
        @max_transactions,       # 3
        @max_flush_wait_time,    # 4
        @events_flush_interval,  # 5
        @event_flush_batch_size, # 6
        @reporter,               # 7
        @host,                   # 8
        @service_key,            # 9
        @certificates,           #10
        @buffer_size,            #11
        @trace_metrics,          #12
        @histogram_precision,    #13
        @token_bucket_capacity,  #14
        @token_bucket_rate,      #15
        @file_single,            #16
        @ec2_md_timeout,         #17
        @grpc_proxy,             #18
        0,                       #19 arg for lambda (no lambda for ruby yet)
        @metric_format,          #20
        @log_type                #21
      ]
    end

    def service_key_ok?
      !@service_key.empty? || @reporter != 'ssl'
    end

    private

    def reporter_and_host

      reporter = ENV['SW_APM_REPORTER'] || 'ssl'

      case reporter
      when 'ssl', 'file'
        host = ENV['SW_APM_COLLECTOR'] || ''
      when 'null'
        host = ''
      else
        host = ''
      end

      host = sanitize_collector_uri(host) unless reporter == 'file'
      [reporter, host]
    end

    def read_and_validate_service_key
      service_key_checker = SolarWindsAPM::ServiceKeyChecker.new(@reporter)
      service_key = service_key_checker.read_and_validate_service_key
      @service_name = service_key.split(':',2).last # instance variable used in testing
      service_key
    end

    def read_and_validate_ec2_md_timeout
      timeout = ENV['SW_APM_EC2_METADATA_TIMEOUT'] || SolarWindsAPM::Config[:ec2_metadata_timeout]
      return 1000 unless timeout.is_a?(Integer) || timeout =~ /^\d+$/

      timeout = timeout.to_i
      timeout.between?(0, 3000) ? timeout : 1000
    end

    def read_and_validate_proxy
      proxy = ENV['SW_APM_PROXY'] || SolarWindsAPM::Config[:http_proxy] || ''
      return proxy if proxy == ''

      unless /http:\/\/.*:\d+$/.match?(proxy)
        SolarWindsAPM.logger.error {"[#{self.class}/#{__method__}] SW_APM_PROXY/http_proxy doesn't start with 'http://', #{proxy}"}
        return '' # try without proxy, it may work, shouldn't crash but may not report
      end

      proxy
    end

    def read_certificates
      certificate = ''

      file = appoptics_collector?? "#{__dir__}/cert/star.appoptics.com.issuer.crt" : ENV['SW_APM_TRUSTEDPATH']
      return certificate if file.nil? || file&.empty?

      begin
        certificate = File.open(file,"r").read
      rescue StandardError => e
        SolarWindsAPM.logger.error {"[#{self.class}/#{__method__}] certificates: #{file} doesn't exist or caused by #{e.message}."}
      end

      certificate
    end

    def determine_the_metric_model
      appoptics_collector? ? 1 : 2
    end

    def appoptics_collector?
      allowed_uri = ['collector.appoptics.com', 'collector-stg.appoptics.com',
                     'collector.appoptics.com:443', 'collector-stg.appoptics.com:443']

      (allowed_uri.include? ENV["SW_APM_COLLECTOR"])? true : false
    end

    def sanitize_collector_uri(uri)
      return uri if uri.nil? || uri.empty?

      begin
        sanitized_uri = ::URI.parse("http://#{uri}").host
        return sanitized_uri unless sanitized_uri.nil?
      rescue StandardError => e
        SolarWindsAPM.logger.error {"[#{self.class}/#{__method__}] uri for collector #{uri} is malformat. Error: #{e.message}"}
      end
      ""
    end

    def determine_oboe_log_type
      log_type = 0
      log_type = 2 unless ENV['SW_APM_LOG_FILEPATH'].to_s.empty?
      log_type = 4 if @debug_level == -1
      log_type
    end
  end
end
