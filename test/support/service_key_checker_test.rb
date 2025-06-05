# frozen_string_literal: true

# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
# require './lib/solarwinds_apm/logger'
require './lib/solarwinds_apm/config'
require './lib/solarwinds_apm/support/service_key_checker'

describe 'ServiceKeyCheckerTest' do
  before do
    @env = ENV.to_hash
    # lets suppress logging, because we will log a lot of errors when testing the service_key
    @log_level = SolarWindsAPM.logger.level
    SolarWindsAPM.logger.level = 6

    ENV.delete('SW_APM_SERVICE_KEY')
    ENV.delete('OTEL_SERVICE_NAME')
    ENV.delete('OTEL_RESOURCE_ATTRIBUTES')
    SolarWindsAPM::Config[:service_key]       = nil
    SolarWindsAPM::Config[:otel_service_name] = nil
  end

  after do
    @env.each { |k, v| ENV[k] = v }

    SolarWindsAPM.logger.level = @log_level
  end

  def service_key_ok?(service_key)
    !service_key.to_s.empty?
  end

  it 'validates the service key' do
    ENV['SW_APM_SERVICE_KEY'] = nil
    SolarWindsAPM::Config[:service_key] = nil

    service_key_checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)
    _(service_key_ok?(service_key_checker.token)).must_equal false

    SolarWindsAPM::Config[:service_key] = '22222222-2222-2222-2222-222222222222:service'
    service_key_checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)
    _(service_key_ok?(service_key_checker.token)).must_equal true

    SolarWindsAPM::Config[:service_key] = 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq'
    service_key_checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)
    _(service_key_ok?(service_key_checker.token)).must_equal false

    SolarWindsAPM::Config[:service_key] = 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:'
    service_key_checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)
    _(service_key_ok?(service_key_checker.token)).must_equal false

    SolarWindsAPM::Config[:service_key] =
      'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:service'
    service_key_checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)
    _(service_key_ok?(service_key_checker.token)).must_equal true

    SolarWindsAPM::Config[:service_key] = nil

    ENV['SW_APM_SERVICE_KEY'] = 'blabla'
    service_key_checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)
    _(service_key_ok?(service_key_checker.token)).must_equal false

    ENV['SW_APM_SERVICE_KEY'] = nil
    service_key_checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)
    _(service_key_ok?(service_key_checker.token)).must_equal false

    ENV['SW_APM_SERVICE_KEY'] = '22222222-2222-2222-2222-222222222222:service'
    service_key_checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)
    _(service_key_ok?(service_key_checker.token)).must_equal true

    ENV['SW_APM_SERVICE_KEY'] = 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq'
    service_key_checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)
    _(service_key_ok?(service_key_checker.token)).must_equal false

    ENV['SW_APM_SERVICE_KEY'] = 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:'
    service_key_checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)
    _(service_key_ok?(service_key_checker.token)).must_equal false

    ENV['SW_APM_SERVICE_KEY'] = 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:service'
    service_key_checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)
    _(service_key_ok?(service_key_checker.token)).must_equal true
  end

  it 'removes invalid characters from the service name' do
    ENV['SW_APM_SERVICE_KEY'] =
      'f7B-kZXtk1sxaJGkv-wew1244444444444444444444444IptKFVPRv0o8keDro9QbKioW4:service#####.:-_0'
    service_key_checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)

    _(service_key_ok?(service_key_checker.token)).must_equal true
    _(service_key_checker.service_name).must_equal 'service.:-_0'
  end

  it 'transforms the service name to lower case' do
    ENV['SW_APM_SERVICE_KEY'] =
      'f7B-kZXtk1sxaJGkv-wew1244444444444444444444444IptKFVPRv0o8keDro9QbKioW4:SERVICE#####.:-_0'
    service_key_checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)

    _(service_key_ok?(service_key_checker.token)).must_equal true
    _(service_key_checker.service_name).must_equal 'service.:-_0'
  end

  it 'shortens the service name to 255 characters' do
    ENV['SW_APM_SERVICE_KEY'] =
      "f7B-kZXtk1sxaJGkv-wew1244444444444444444444444IptKFVPRv0o8keDro9QbKioW4:SERV#_#{'1234567890' * 26}"
    service_key_checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)

    _(service_key_ok?(service_key_checker.token)).must_equal true
    _(service_key_checker.service_name).must_equal "serv_#{'1234567890' * 25}"
  end

  it 'test_when_otel_service_name_exist' do
    ENV['OTEL_SERVICE_NAME'] = 'abcdef'
    ENV['SW_APM_SERVICE_KEY'] =
      'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:my-cool-service'
    service_key_checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)

    _(service_key_ok?(service_key_checker.token)).must_equal true
    _(service_key_checker.service_name).must_equal 'abcdef'

    ENV['OTEL_SERVICE_NAME'] = nil
    ENV['SW_APM_SERVICE_KEY'] =
      'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:my-cool-service'
    service_key_checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)

    _(service_key_ok?(service_key_checker.token)).must_equal true
    _(service_key_checker.service_name).must_equal 'my-cool-service'

    ENV['OTEL_SERVICE_NAME']  = ''
    ENV['SW_APM_SERVICE_KEY'] =
      'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:my-cool-service'
    service_key_checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)

    _(service_key_ok?(service_key_checker.token)).must_equal true
    _(service_key_checker.service_name).must_equal 'my-cool-service'
  end

  it 'test_when_otel_service_name_does_not_exist' do
    ENV['SW_APM_SERVICE_KEY'] =
      'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:my-cool-service'
    ENV['OTEL_SERVICE_NAME']  = nil
    SolarWindsAPM::ServiceKeyChecker.new('ssl', false)

    _(ENV.fetch('OTEL_SERVICE_NAME', nil)).must_equal 'my-cool-service'

    ENV['OTEL_SERVICE_NAME']  = nil
    ENV['SW_APM_SERVICE_KEY'] = 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq'
    SolarWindsAPM::ServiceKeyChecker.new('ssl', false)

    assert_nil(ENV.fetch('OTEL_SERVICE_NAME', nil))

    ENV['OTEL_SERVICE_NAME']  = nil
    ENV['SW_APM_SERVICE_KEY'] = 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:'
    SolarWindsAPM::ServiceKeyChecker.new('ssl', false)

    assert_nil(ENV.fetch('OTEL_SERVICE_NAME', nil))
  end

  it 'test_with_OTEL_RESOURCE_ATTRIBUTES_and_OTEL_SERVICE_NAME' do
    ENV['SW_APM_SERVICE_KEY'] =
      'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:my-cool-service'
    ENV['OTEL_SERVICE_NAME']  = nil
    ENV['OTEL_RESOURCE_ATTRIBUTES'] = 'service.name=my-chill-service'
    SolarWindsAPM::ServiceKeyChecker.new('ssl', false)

    _(ENV.fetch('OTEL_SERVICE_NAME', nil)).must_equal 'my-chill-service'

    ENV['SW_APM_SERVICE_KEY'] =
      'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:my-cool-service'
    ENV['OTEL_SERVICE_NAME']  = 'my-service-name'
    ENV['OTEL_RESOURCE_ATTRIBUTES'] = 'service.name=my-chill-service'
    SolarWindsAPM::ServiceKeyChecker.new('ssl', false)

    _(ENV.fetch('OTEL_SERVICE_NAME', nil)).must_equal 'my-service-name'

    ENV['SW_APM_SERVICE_KEY'] =
      'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:my-cool-service'
    ENV['OTEL_SERVICE_NAME']  = 'my-service-name'
    ENV['OTEL_RESOURCE_ATTRIBUTES'] = nil
    SolarWindsAPM::ServiceKeyChecker.new('ssl', false)

    _(ENV.fetch('OTEL_SERVICE_NAME', nil)).must_equal 'my-service-name'

    ENV['SW_APM_SERVICE_KEY'] =
      'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:my-cool-service'
    ENV['OTEL_SERVICE_NAME']  = nil
    ENV['OTEL_RESOURCE_ATTRIBUTES'] = nil
    SolarWindsAPM::ServiceKeyChecker.new('ssl', false)

    _(ENV.fetch('OTEL_SERVICE_NAME', nil)).must_equal 'my-cool-service'

    ENV['SW_APM_SERVICE_KEY'] = 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:'
    ENV['OTEL_SERVICE_NAME']  = nil
    ENV['OTEL_RESOURCE_ATTRIBUTES'] = nil
    SolarWindsAPM::ServiceKeyChecker.new('ssl', false)

    assert_nil(ENV.fetch('OTEL_SERVICE_NAME', nil))

    ENV['SW_APM_SERVICE_KEY'] = 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:'
    ENV['OTEL_SERVICE_NAME']  = 'my-cool-service'
    ENV['OTEL_RESOURCE_ATTRIBUTES'] = nil
    SolarWindsAPM::ServiceKeyChecker.new('ssl', false)

    assert_nil(ENV.fetch('OTEL_SERVICE_NAME', nil))

    ENV['SW_APM_SERVICE_KEY'] = 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:'
    ENV['OTEL_SERVICE_NAME']  = nil
    ENV['OTEL_RESOURCE_ATTRIBUTES'] = 'service.name=my-chill-service'
    SolarWindsAPM::ServiceKeyChecker.new('ssl', false)

    assert_nil(ENV.fetch('OTEL_SERVICE_NAME', nil))

    ENV['SW_APM_SERVICE_KEY'] = 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq:'
    ENV['OTEL_SERVICE_NAME']  = 'my-cool-service'
    ENV['OTEL_RESOURCE_ATTRIBUTES'] = 'service.name=my-chill-service'
    SolarWindsAPM::ServiceKeyChecker.new('ssl', false)

    assert_nil(ENV.fetch('OTEL_SERVICE_NAME', nil))

    ENV['SW_APM_SERVICE_KEY'] = 'CWoadXY66FXNd_e5u3nabLZ1KByYZRTi1yWJg2AcD6MHo1AA42UstbipfHfx6Hnl-821ARq'
    ENV['OTEL_SERVICE_NAME']  = nil
    ENV['OTEL_RESOURCE_ATTRIBUTES'] = nil
    SolarWindsAPM::ServiceKeyChecker.new('ssl', false)

    assert_nil(ENV.fetch('OTEL_SERVICE_NAME', nil))
  end
end
