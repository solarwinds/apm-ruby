# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'SolarWinds TransactionCache Test' do
  before do
    SolarWindsAPM::TransactionCache.initialize
  end

  it 'test set and get' do
    SolarWindsAPM::TransactionCache.set('a','b')
    _(SolarWindsAPM::TransactionCache.get("a")).must_equal "b"
  end

  it 'test del' do
    SolarWindsAPM::TransactionCache.set('a','b')
    SolarWindsAPM::TransactionCache.del('a')
    _(SolarWindsAPM::TransactionCache.get("a")).must_equal nil
  end
end
