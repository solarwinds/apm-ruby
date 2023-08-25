# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/support/txn_name_manager'

describe 'SolarWindsTXNNameManangerTest.rb' do
  before do

    @txn_manager = SolarWindsAPM::OpenTelemetry::TxnNameManager.new
    @txn_manager.set("c","d")
  end

  it 'test_set' do
    @txn_manager.set("a","b")
    _(@txn_manager.get("a")).must_equal "b"
  end

  it 'test_[]' do
    @txn_manager["e"] = "f"
    _(@txn_manager.get("e")).must_equal "f"
  end

  it 'test_del' do
    @txn_manager.del("c")
    _(@txn_manager.get("c")).must_equal nil
  end

  it 'test_get' do
    @txn_manager.get("c").must_equal "d"
  end

  it 'test_set_get_root_context' do
    @txn_manager.set_root_context('abcd')
    _(@txn_manager.get_root_context).must_equal 'abcd'
  end
end
