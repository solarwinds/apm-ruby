# frozen_string_literal: true

# Copyright (c) 2019 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/config'
require './lib/solarwinds_apm/support/service_key_checker'
require './lib/solarwinds_apm/support/utils'

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

  it 'accepts valid token:service format and rejects malformed service keys' do
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

  it 'uses OTEL_SERVICE_NAME as service name when set and non-empty' do
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

  it 'sets OTEL_SERVICE_NAME from service key when OTEL_SERVICE_NAME is not set' do
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

  it 'resolves service name with OTEL_SERVICE_NAME over OTEL_RESOURCE_ATTRIBUTES and service key' do
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

describe 'ServiceKeyChecker token/service_name parsing, env var overrides, and name sanitization' do
  describe 'initialization' do
    it 'returns nil token for non-ssl reporter' do
      checker = SolarWindsAPM::ServiceKeyChecker.new('udp', false)
      assert_nil checker.token
      assert_nil checker.service_name
    end

    it 'returns nil token for lambda environment' do
      checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', true)
      assert_nil checker.token
      assert_nil checker.service_name
    end

    it 'parses valid service key from environment' do
      original_key = ENV['SW_APM_SERVICE_KEY']
      ENV['SW_APM_SERVICE_KEY'] = 'test-token-key-123456789012345678901234567890123:my-service'
      ENV.delete('OTEL_SERVICE_NAME')
      ENV.delete('OTEL_RESOURCE_ATTRIBUTES')

      checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)
      assert_equal 'test-token-key-123456789012345678901234567890123', checker.token
      assert_equal 'my-service', checker.service_name
    ensure
      ENV['SW_APM_SERVICE_KEY'] = original_key
    end

    it 'returns nil token for empty service key' do
      original_key = ENV['SW_APM_SERVICE_KEY']
      ENV['SW_APM_SERVICE_KEY'] = ''

      checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)
      assert_nil checker.token
    ensure
      ENV['SW_APM_SERVICE_KEY'] = original_key
    end

    it 'returns nil token for missing service name' do
      original_key = ENV['SW_APM_SERVICE_KEY']
      ENV['SW_APM_SERVICE_KEY'] = 'only-token-no-colon'
      ENV.delete('OTEL_SERVICE_NAME')

      checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)
      assert_nil checker.token
    ensure
      ENV['SW_APM_SERVICE_KEY'] = original_key
    end

    it 'uses OTEL_SERVICE_NAME override' do
      original_key = ENV['SW_APM_SERVICE_KEY']
      original_otel = ENV['OTEL_SERVICE_NAME']
      ENV['SW_APM_SERVICE_KEY'] = 'test-token-key-123456789012345678901234567890123:original-service'
      ENV['OTEL_SERVICE_NAME'] = 'otel-override'

      checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)
      assert_equal 'otel-override', checker.service_name
    ensure
      ENV['SW_APM_SERVICE_KEY'] = original_key
      ENV['OTEL_SERVICE_NAME'] = original_otel
    end

    it 'uses OTEL_RESOURCE_ATTRIBUTES service.name override' do
      original_key = ENV['SW_APM_SERVICE_KEY']
      original_otel = ENV['OTEL_SERVICE_NAME']
      original_resource = ENV['OTEL_RESOURCE_ATTRIBUTES']
      ENV['SW_APM_SERVICE_KEY'] = 'test-token-key-123456789012345678901234567890123:original-service'
      ENV.delete('OTEL_SERVICE_NAME')
      ENV['OTEL_RESOURCE_ATTRIBUTES'] = 'service.name=resource-service,other=val'

      checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)
      assert_equal 'resource-service', checker.service_name
    ensure
      ENV['SW_APM_SERVICE_KEY'] = original_key
      ENV['OTEL_SERVICE_NAME'] = original_otel
      ENV['OTEL_RESOURCE_ATTRIBUTES'] = original_resource
    end

    it 'transforms service name by lowercasing and removing invalid chars' do
      original_key = ENV['SW_APM_SERVICE_KEY']
      ENV['SW_APM_SERVICE_KEY'] = 'test-token-key-123456789012345678901234567890123:My Service!@#$'
      ENV.delete('OTEL_SERVICE_NAME')
      ENV.delete('OTEL_RESOURCE_ATTRIBUTES')

      checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)
      assert_equal 'myservice', checker.service_name
    ensure
      ENV['SW_APM_SERVICE_KEY'] = original_key
    end

    it 'truncates long service names to 255 chars' do
      original_key = ENV['SW_APM_SERVICE_KEY']
      long_name = 'a' * 300
      ENV['SW_APM_SERVICE_KEY'] = "test-token-key-123456789012345678901234567890123:#{long_name}"
      ENV.delete('OTEL_SERVICE_NAME')
      ENV.delete('OTEL_RESOURCE_ATTRIBUTES')

      checker = SolarWindsAPM::ServiceKeyChecker.new('ssl', false)
      assert checker.service_name.length <= 255
    ensure
      ENV['SW_APM_SERVICE_KEY'] = original_key
    end
  end
end
