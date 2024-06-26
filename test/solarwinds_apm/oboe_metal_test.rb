# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'Oboe Metal Test' do
  describe 'Reporter Test' do
    before do
      module SolarWindsAPM # rubocop:disable Lint/ConstantDefinitionInBlock
        module Oboe_metal # rubocop:disable Naming/ClassAndModuleCamelCase
          class Reporter
            def initialize(*); end
          end
        end
      end

      require './lib/oboe_metal'
      require './lib/solarwinds_apm/config'
      require './lib/solarwinds_apm/oboe_init_options'
    end

    it 'test_report_init' do
      log_output = StringIO.new
      SolarWindsAPM.logger = Logger.new(log_output)
      SolarWindsAPM.loaded = true
      SolarWindsAPM::Reporter.send(:report_init, :rack)
      assert_includes log_output.string, 'Init message has been sent.'
    end

    it 'test_reporter_start' do
      log_output = StringIO.new
      SolarWindsAPM.logger = Logger.new(log_output)
      SolarWindsAPM::Reporter.start
      assert_includes log_output.string, 'Init message has been sent.'
    end

    it 'test_build_swo_init_report_with_error' do
      platform_info = SolarWindsAPM::Reporter.send(:build_swo_init_report)
      _(platform_info['__Init']).must_equal true
      _(platform_info['APM.Version'].nil?).must_equal false
      _(platform_info['Error'].nil?).must_equal false
    end

    it 'test_build_swo_init_report_without_error' do
      module Gem # rubocop:disable Lint/ConstantDefinitionInBlock
        class Specification
          def self.find_by_name(_name, *requirements)
            Gem::Dependency.new('irb', *requirements).to_spec
          end
        end
      end

      SolarWindsAPM::Reporter.stub(:extension_lib_version, '0.0.1') do
        platform_info = SolarWindsAPM::Reporter.send(:build_swo_init_report)
        _(platform_info['__Init']).must_equal true
        _(platform_info['APM.Version']).wont_be_nil
        _(platform_info['APM.Extension.Version']).must_equal '0.0.1'
        _(platform_info['process.executable.path']).wont_be_nil
        _(platform_info['process.executable.name']).must_equal 'ruby'
        _(platform_info['process.command_line']).wont_be_nil
        _(platform_info['process.telemetry.path']).wont_be_nil
        _(platform_info['os.type']).wont_be_nil
        _(platform_info['Ruby.irb.Version']).wont_be_nil
        _(platform_info['telemetry.sdk.name']).must_equal 'opentelemetry'
        _(platform_info['process.runtime.name']).must_equal 'ruby'
      end
    end
  end
end
