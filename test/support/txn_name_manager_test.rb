# frozen_string_literal: true

# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/support/txn_name_manager'

describe 'TxnNameManager CRUD operations, name length/cardinality limits, and root context tracking' do
  before do
    @txn_manager = SolarWindsAPM::TxnNameManager.new
  end

  it 'creates a cleanup thread for transaction name cache' do
    @txn_manager.set('c', 'd')
    _(@txn_manager.instance_variable_get(:@transaction_name)['d'].class).must_equal Thread
  end

  describe 'set and get' do
    it 'stores and retrieves values' do
      @txn_manager.set('key1', 'value1')
      assert_equal 'value1', @txn_manager.get('key1')
    end

    it 'limits to MAX_TXN_NAME_LENGTH' do
      long_name = 'a' * 500
      @txn_manager.set('key1', long_name)
      result = @txn_manager.get('key1')
      assert result.length <= SolarWindsAPM::Constants::MAX_TXN_NAME_LENGTH
    end

    it 'replaces existing transaction name' do
      @txn_manager.set('key1', 'first')
      @txn_manager.set('key1', 'second')
      assert_equal 'second', @txn_manager.get('key1')
    end

    it 'returns default name when cardinality limit reached' do
      # Fill up with unique names
      SolarWindsAPM::TxnNameManager::MAX_CARDINALITY.times do |i|
        @txn_manager.set("key_#{i}", "unique_name_#{i}")
      end

      # Next new unique name should get default
      @txn_manager.set('overflow_key', 'new_unique_name')
      assert_equal 'other', @txn_manager.get('overflow_key')
    end
  end

  describe 'del' do
    it 'removes stored values' do
      @txn_manager.set('key1', 'value1')
      @txn_manager.del('key1')
      assert_nil @txn_manager.get('key1')
    end

    it 'handles deletion of non-existent key' do
      @txn_manager.del('nonexistent')
      assert_nil @txn_manager.get('nonexistent')
    end
  end

  describe 'root_context_h' do
    it 'sets and gets root context' do
      @txn_manager.set_root_context_h('trace1', 'span1-01')
      assert_equal 'span1-01', @txn_manager.get_root_context_h('trace1')
    end

    it 'deletes root context' do
      @txn_manager.set_root_context_h('trace1', 'span1-01')
      @txn_manager.delete_root_context_h('trace1')
      assert_nil @txn_manager.get_root_context_h('trace1')
    end

    it 'returns nil for non-existent root context' do
      assert_nil @txn_manager.get_root_context_h('nonexistent')
    end
  end

  describe '[]= alias' do
    it 'works as alias for set' do
      @txn_manager['alias_key'] = 'alias_value'
      assert_equal 'alias_value', @txn_manager.get('alias_key')
    end
  end
end
