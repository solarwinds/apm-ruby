# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'SolarWinds TransactionCache Test' do
  before do
    SolarWindsOTelAPM::TransactionCache.initialize
  end

  it 'test set and get' do
    SolarWindsOTelAPM::TransactionCache.set('a','b')
    _(SolarWindsOTelAPM::TransactionCache.get("a")).must_equal "b"
  end

  it 'test del' do
    SolarWindsOTelAPM::TransactionCache.set('a','b')
    SolarWindsOTelAPM::TransactionCache.del('a')
    _(SolarWindsOTelAPM::TransactionCache.get("a")).must_equal nil
  end
end
