# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  # OTelConfig module
  # For configure otel component: configurable: propagator, exporter
  #                               non-config: sampler, processor, response_propagator
  # Level of this configuration: SolarWindsOTel::Config -> OboeOption -> SolarWindsOTel::OTelConfig
  module OTelConfig
    @@config           = {}
    @@config_map       = {}

    @@agent_enabled    = true

    def self.disable_agent(reason: nil)
      return unless @@agent_enabled # only show the msg once

      @@agent_enabled = false
      SolarWindsAPM.logger.warn { "[#{name}/#{__method__}] SolarWindsAPM disabled. No Trace exported. Reason: #{reason}" }
    end

    def self.resolve_sampler
      sampler_config = { 'trigger_trace' => SolarWindsAPM::Config[:trigger_tracing_mode] }
      @@config[:sampler] =
        ::OpenTelemetry::SDK::Trace::Samplers.parent_based(
          root: SolarWindsAPM::OpenTelemetry::SolarWindsSampler.new(sampler_config),
          remote_parent_sampled: SolarWindsAPM::OpenTelemetry::SolarWindsSampler.new(sampler_config),
          remote_parent_not_sampled: SolarWindsAPM::OpenTelemetry::SolarWindsSampler.new(sampler_config)
        )
    end

    #
    # append/add solarwinds_response_propagator into rack instrumentation
    #
    def self.resolve_response_propagator
      response_propagator  = SolarWindsAPM::OpenTelemetry::SolarWindsResponsePropagator::TextMapPropagator.new
      rack_setting         = @@config_map['OpenTelemetry::Instrumentation::Rack']

      if rack_setting
        if rack_setting[:response_propagators].instance_of?(Array)
          rack_setting[:response_propagators].append(response_propagator)
        elsif rack_setting[:response_propagators].nil?
          rack_setting[:response_propagators] = [response_propagator]
        else
          SolarWindsAPM.logger.warn do
            "[#{name}/#{__method__}] Rack response propagator resolve failed. Provided type #{rack_setting[:response_propagators].class}, please provide Array e.g. [#{rack_setting[:response_propagators]}]"
          end
        end
      else
        @@config_map['OpenTelemetry::Instrumentation::Rack'] = { response_propagators: [response_propagator] }
      end
    end

    def self.[](key)
      @@config[key.to_sym]
    end

    def self.print_config
      @@config.each do |k, v|
        SolarWindsAPM.logger.debug { "[#{name}/#{__method__}] Config Key/Value: #{k}, #{v.class}" }
      end
      @@config_map.each do |k, v|
        SolarWindsAPM.logger.debug { "[#{name}/#{__method__}] Config Key/Value: #{k}, #{v}" }
      end
      nil
    end

    def self.resolve_solarwinds_processor
      txn_manager = SolarWindsAPM::TxnNameManager.new
      exporter = SolarWindsAPM::OpenTelemetry::SolarWindsExporter.new(txn_manager: txn_manager)
      @@config[:metrics_processor] = SolarWindsAPM::OpenTelemetry::SolarWindsProcessor.new(txn_manager)
      @@config[:span_processor] = ::OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(exporter)
    end

    def self.resolve_solarwinds_propagator
      @@config[:propagators] = SolarWindsAPM::OpenTelemetry::SolarWindsPropagator::TextMapPropagator.new
    end

    def self.validate_propagator(propagators)
      if propagators.nil?
        disable_agent(reason: 'propagators are invaliad.')
        return
      end

      SolarWindsAPM.logger.debug { "[#{name}/#{__method__}] propagators: #{propagators.map(&:class)}" }
      disable_agent(reason: 'Missing tracecontext propagator.') unless ([::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator, ::OpenTelemetry::Baggage::Propagation::TextMapPropagator] - propagators.map(&:class)).empty?
    end

    def self.initialize
      unless defined?(::OpenTelemetry::SDK::Configurator)
        disable_agent(reason: 'missing OpenTelemetry::SDK::Configurator; opentelemetry seems not loaded.')
        return
      end

      resolve_sampler
      resolve_solarwinds_propagator
      resolve_solarwinds_processor
      resolve_response_propagator

      print_config if SolarWindsAPM.logger.level.zero?

      # resolve OTEL environmental variables
      ENV['OTEL_TRACES_EXPORTER'] = 'none' if ENV['OTEL_TRACES_EXPORTER'].to_s.empty?
      if ENV['OTEL_LOG_LEVEL'].to_s.empty?
        log_level = (ENV['SW_APM_DEBUG_LEVEL'] || SolarWindsAPM::Config[:debug_level] || 3).to_i
        ENV['OTEL_LOG_LEVEL'] = SolarWindsAPM::Config::SW_LOG_LEVEL_MAPPING.dig(log_level, :otel)
      end

      ::OpenTelemetry::SDK.configure { |c| c.use_all(@@config_map) }

      validate_propagator(::OpenTelemetry.propagation.instance_variable_get(:@propagators))

      return unless @@agent_enabled

      # append our propagators
      ::OpenTelemetry.propagation.instance_variable_get(:@propagators).append(@@config[:propagators])

      # append our processors (with our exporter)
      ::OpenTelemetry.tracer_provider.add_span_processor(@@config[:metrics_processor])
      ::OpenTelemetry.tracer_provider.add_span_processor(@@config[:span_processor])

      # configure sampler afterwards
      ::OpenTelemetry.tracer_provider.sampler = @@config[:sampler]

      if ENV['SW_APM_AUTO_CONFIGURE'] == 'false'
        SolarWindsAPM.logger.info '==================================================================='
        SolarWindsAPM.logger.info "\e[1mSolarWindsAPM manual initialization was successful.\e[0m"
        SolarWindsAPM.logger.info '==================================================================='
      end

      nil
    end

    #
    # Allow initialize after set new value to SolarWindsAPM::Config[:key]=value
    #
    # Usage:
    #
    # Default using the use_all to load all instrumentation
    # But with specific instrumentation disabled, use {:enabled: false} in config
    # SolarWindsAPM::OTelConfig.initialize_with_config do |config|
    #   config["OpenTelemetry::Instrumentation::Rack"]  = {"a" => "b"}
    #   config["OpenTelemetry::Instrumentation::Dalli"] = {:enabled: false}
    # end
    #
    def self.initialize_with_config
      unless block_given?
        SolarWindsAPM.logger.warn do
          "[#{name}/#{__method__}] Block not given while doing in-code configuration. Agent disabled."
        end
        return
      end

      yield @@config_map

      if @@config_map.empty?
        SolarWindsAPM.logger.warn do
          "[#{name}/#{__method__}] No configuration given for in-code configuration. Agent disabled."
        end
        return
      end

      initialize
    end
  end
end
