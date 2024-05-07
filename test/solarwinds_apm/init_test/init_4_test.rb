# frozen_string_literal: true

# Copyright (c) 2024 SolarWinds, LLC.
# All rights reserved.

require 'initest_helper'

describe 'solarwinds_apm_init_4' do
  it 'RUBY_PLATFORM_is_non_linux' do
    puts "\n\033[1m=== TEST RUN: #{RUBY_VERSION} #{File.basename(__FILE__)} #{Time.now.strftime('%Y-%m-%d %H:%M')} ===\033[0m\n"

    log_output = StringIO.new
    SolarWindsAPM.logger = Logger.new(log_output)

    RUBY_PLATFORM = 'macos' # rubocop:disable Lint/ConstantDefinitionInBlock

    require './lib/solarwinds_apm'
    assert_includes log_output.string,
                    'SolarWindsAPM warning: Platform macos not yet supported on current solarwinds_apm'

    noop_shared_test
  end
end
