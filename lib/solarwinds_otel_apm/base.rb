# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

# Constants from liboboe
SW_APM_TRACE_DISABLED   = 0
SW_APM_TRACE_ENABLED  = 1

SAMPLE_RATE_MASK   = 0b0000111111111111111111111111
SAMPLE_SOURCE_MASK = 0b1111000000000000000000000000

# w3c trace context related global constants
# see: https://www.w3.org/TR/trace-context/#tracestate-limits
SW_APM_TRACESTATE_ID = 'sw'.freeze
SW_APM_MAX_TRACESTATE_BYTES = 512
SW_APM_MAX_TRACESTATE_MEMBER_BYTES = 128

SW_APM_STR_LAYER = 'Layer'.freeze
SW_APM_STR_LABEL = 'Label'.freeze

##
# This module is the base module for SolarWindsOTelAPM reporting.
#
module SolarWindsOTelAPMBase
  extend SolarWindsOTelAPM::ThreadLocal

  attr_accessor :reporter
  attr_accessor :loaded
  
  thread_local :sample_source
  thread_local :sample_rate
  thread_local :layer
  thread_local :layer_op

  # trace context is used to store incoming w3c trace information
  thread_local :trace_context

  # transaction_name is used for custom transaction naming
  # It needs to be globally accessible, but is only set by the request processors of the different frameworks
  # and read by rack
  thread_local :transaction_name

  # Semaphore used during the test suite to test
  # global config options.
  thread_local :config_lock


  ##
  # tracing_layer?
  #
  # Queries the thread local variable about the current
  # layer being traced.  This is used in cases of recursive
  # operation tracing or one instrumented operation calling another.
  #
  def tracing_layer?(layer)
    SolarWindsOTelAPM.layer == layer.to_sym
  end

  ##
  # tracing_layer_op?
  #
  # Queries the thread local variable about the current
  # operation being traced.  This is used in cases of recursive
  # operation tracing or one instrumented operation calling another.
  #
  # In such cases, we only want to trace the outermost operation.
  #
  def tracing_layer_op?(operation)
    unless SolarWindsOTelAPM.layer_op.nil? || SolarWindsOTelAPM.layer_op.is_a?(Array)
      SolarWindsOTelAPM.logger.error('[SolarWindsOTelAPM/logging] INTERNAL: layer_op should be nil or an array, please report to technicalsupport@solarwinds.com')
      return false
    end

    return false if SolarWindsOTelAPM.layer_op.nil? || SolarWindsOTelAPM.layer_op.empty? || !operation.respond_to?(:to_sym)
    SolarWindsOTelAPM.layer_op.last == operation.to_sym
  end

  # TODO review use of these boolean statements
  # ____ they should now be handled by TransactionSettings,
  # ____ because there can be exceptions to :enabled and :disabled

  ##
  # Returns true if the tracing_mode is set to :enabled.
  # False otherwise
  #
  def tracing_enabled?
    SolarWindsOTelAPM::Config[:tracing_mode] &&
      [:enabled, :always].include?(SolarWindsOTelAPM::Config[:tracing_mode].to_sym)
  end

  ##
  # Returns true if the tracing_mode is set to :disabled.
  # False otherwise
  #
  def tracing_disabled?
    SolarWindsOTelAPM::Config[:tracing_mode] &&
      [:disabled, :never].include?(SolarWindsOTelAPM::Config[:tracing_mode].to_sym)
  end

  ##
  # Returns true if we are currently tracing a request
  # False otherwise
  #
  def tracing?
    SolarWindsOTelAPM.logger.debug "#{SolarWindsOTelAPM.loaded} #{SolarWindsOTelAPM::Context.isSampled} result======#######"
    return false unless SolarWindsOTelAPM.loaded # || SolarWindsOTelAPM.tracing_disabled?
    
    SolarWindsOTelAPM::Context.isSampled
  end

  def heroku?
    ENV.key?('SW_APM_URL')
  end

  ##
  # Determines if we are running under a forking webserver
  #
  def forking_webserver?
    if (defined?(::Unicorn) && ($PROGRAM_NAME =~ /unicorn/i)) ||
       (defined?(::Puma) && ($PROGRAM_NAME =~ /puma/i))
      true
    else
      false
    end
  end

  ##
  # These methods should be implemented by the descendants
  # currently only Oboe_metal
  #
  def sample?(_opts = {})
    raise 'sample? should be implemented by metal layer.'
  end

  def log(_layer, _label, _options = {})
    raise 'log should be implemented by metal layer.'
  end

  def tracing_mode(_mode)
    raise 'tracing_mode should be implemented by metal layer.'
  end

  def sample_rate(_rate)
    raise 'sample_rate should be implemented by metal layer.'
  end
end

module SolarWindsOTelAPM
  extend SolarWindsOTelAPMBase
end

# Setup an alias so we don't bug users
# about single letter capitalization
SolarwindsOTelAPM = SolarWindsOTelAPM
SolarWindsOtelApm = SolarWindsOTelAPM
SolarwindsotelApm = SolarWindsOTelAPM
SolarwindsOTELApm = SolarWindsOTelAPM
SolarwindsOTELAPM = SolarWindsOTelAPM
