# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'mocha/minitest'

describe 'SolarWindsOTelAPMBase' do
  describe 'tracing_layer_op?' do
    after do
      SolarWindsOTelAPM.layer_op = nil
    end

    it 'should return false for nil op' do
      refute SolarWindsOTelAPM.tracing_layer_op?(nil)
    end

    it 'should return false for op that cannot be symbolized' do
      refute SolarWindsOTelAPM.tracing_layer_op?([1, 2])
    end

    it 'should return false when layer_op is nil' do
      SolarWindsOTelAPM.layer_op = nil
      refute SolarWindsOTelAPM.tracing_layer_op?('whoot?')
    end

    it 'should return false when layer_op is empty' do
      SolarWindsOTelAPM.layer_op = []
      refute SolarWindsOTelAPM.tracing_layer_op?('well?')
    end

    # this should be prevented otherwise, but how?
    # also layer_op should only contain symbols!
    it 'should log an error and return false when layer_op is not an array' do
      SolarWindsOTelAPM.logger.expects(:error)
      SolarWindsOTelAPM.layer_op = 'I should no be a string'
      refute SolarWindsOTelAPM.tracing_layer_op?(nil)
    end

    it 'should return true when op is last in layer_op' do
      SolarWindsOTelAPM.layer_op = [:one]
      assert SolarWindsOTelAPM.tracing_layer_op?('one')
      SolarWindsOTelAPM.layer_op = [:one, :two]
      assert SolarWindsOTelAPM.tracing_layer_op?('two')
    end

    it 'should return false when op is not last in layer_op' do
      SolarWindsOTelAPM.layer_op = [:one, :two]
      refute SolarWindsOTelAPM.tracing_layer_op?('one')
    end

    it 'should return false when op is not in layer_op' do
      SolarWindsOTelAPM.layer_op = [:one, :two]
      refute SolarWindsOTelAPM.tracing_layer_op?('three')
    end
  end

  describe 'thread local variables' do
    it "SolarWindsOTelAPM.trace_context instances are thread local" do
      contexts = []
      ths = []
      2.times do |i|
        ths << Thread.new do
          trace_00 = "00-#{i}435a9fe510ae4533414d425dadf4e18-#{i}9e60702469db05f-00"
          state_00 = "sw=#{i}9e60702469db05f-00"
          headers = { traceparent: trace_00, tracestate: state_00 }
          SolarWindsOTelAPM.trace_context = SolarWindsOTelAPM::TraceContext.new(headers)

          contexts[i] = [SolarWindsOTelAPM.trace_context.traceparent,
                         SolarWindsOTelAPM.trace_context.tracestate,
                         SolarWindsOTelAPM.trace_context.sw_member_value]
        end
      end
      ths.each { |th| th.join }
      assert contexts[0]
      assert contexts[1]
      refute_equal contexts[0][0], contexts[1][0]
      refute_equal contexts[0][1], contexts[1][1]
      refute_equal contexts[0][2], contexts[1][2]
    end
  end

end