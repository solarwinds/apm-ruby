# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'

describe 'SolarWindsTXNNameManangerTest.rb' do
  before do

    @txn_manager = SolarWindsOTelAPM::OpenTelemetry::SolarWindsTxnNameManager.new
    @txn_manager.set("c","d")
  end

  it 'test set' do
    @txn_manager.set("a","b")
    _(@txn_manager.get("a")).must_equal "b"
  end

  it 'test []' do
    @txn_manager["e"] = "f"
    _(@txn_manager.get("e")).must_equal "f"
  end

  it 'test del' do
    @txn_manager.del("c")
     _(@txn_manager.get("c")).must_equal nil
  end

  it 'test get' do
    @txn_manager.get("c").must_equal "d"
  end

end
