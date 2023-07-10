# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'mocha/minitest'

describe 'SolarWindsAPMBase' do
  
  describe 'thread local variables' do
    it "SolarWindsAPM.trace_context instances are thread local" do
      contexts = []
      ths = []
      2.times do |i|
        ths << Thread.new do
          trace_ = "#{i}435a9fe510ae4533414d425dadf4e18"
          span_  = "#{i}9e60702469db05f"
          state_ = "sw=#{i}9e60702469db05f-00"
          trace_state = ::OpenTelemetry::Trace::Tracestate.from_string(state_)
          context = ::OpenTelemetry::Trace::SpanContext.new(trace_id: trace_, span_id: span_, tracestate: trace_state)

          contexts[i] = [context.trace_id,
                         context.span_id,
                         context.tracestate['sw']]
        end
      end
      ths.each(&:join)
      # ths.map(&:join)
      assert contexts[0]
      assert contexts[1]
      refute_equal contexts[0][0], contexts[1][0]
      refute_equal contexts[0][1], contexts[1][1]
      refute_equal contexts[0][2], contexts[1][2]
    end
  end

end