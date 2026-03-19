# frozen_string_literal: true

# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require './lib/solarwinds_apm/support/txn_name_manager'

describe 'SolarWindsTXNNameManangerTest.rb' do
  before do
    @txn_manager = SolarWindsAPM::TxnNameManager.new
  end

  after do
    @txn_manager.stop
  end

  it 'test_set' do
    @txn_manager.set('a', 'b')
    _(@txn_manager.get('a')).must_equal 'b'
  end

  it 'test_[]' do
    @txn_manager['e'] = 'f'
    _(@txn_manager.get('e')).must_equal 'f'
  end

  it 'test_del' do
    @txn_manager.set('c', 'd')
    @txn_manager.del('c')
    assert_nil(@txn_manager.get('c'))
  end

  it 'test_get' do
    @txn_manager.set('c', 'd')
    _(@txn_manager.get('c')).must_equal 'd'
  end

  it 'test_set_get_root_context' do
    @txn_manager.set_root_context_h('key1', 'abcd')
    _(@txn_manager.get_root_context_h('key1')).must_equal 'abcd'
  end

  it 'transaction_name tracks expiry' do
    @txn_manager.set('c', 'd')
    expiry = @txn_manager.instance_variable_get(:@transaction_name)['d']
    _(expiry.class).must_equal Integer
    assert expiry > Time.now.to_i
  end

  describe 'cardinality management' do
    it 'caps transaction name at DEFAULT_TXN_NAME when cardinality limit reached' do
      SolarWindsAPM::TxnNameManager::MAX_CARDINALITY.times do |i|
        @txn_manager.set("key_#{i}", "unique_name_#{i}")
      end

      @txn_manager.set('overflow_key', 'overflow_name')
      _(@txn_manager.get('overflow_key')).must_equal SolarWindsAPM::TxnNameManager::DEFAULT_TXN_NAME
    end

    it 'allows renewal of existing name when pool is at max cardinality' do
      SolarWindsAPM::TxnNameManager::MAX_CARDINALITY.times do |i|
        @txn_manager.set("key_#{i}", "unique_name_#{i}")
      end

      # 'unique_name_0' is already in pool — setting another key to it should succeed
      @txn_manager.set('new_key', 'unique_name_0')
      _(@txn_manager.get('new_key')).must_equal 'unique_name_0'
    end

    it 'renewal updates the expiry for an existing transaction name' do
      @txn_manager.set('c', 'd')
      old_expiry = @txn_manager.instance_variable_get(:@transaction_name)['d']
      sleep(1)
      @txn_manager.set('c', 'd')
      new_expiry = @txn_manager.instance_variable_get(:@transaction_name)['d']
      assert new_expiry > old_expiry
    end
  end

  describe 'heap structure' do
    it 'expiry heap size grows with each unique transaction name' do
      initial_size = @txn_manager.instance_variable_get(:@expiry_heap).size
      @txn_manager.set('k1', 'alpha')
      @txn_manager.set('k2', 'beta')

      heap = @txn_manager.instance_variable_get(:@expiry_heap)
      _(heap.size).must_equal initial_size + 2
    end

    it 'expiry heap root holds the earliest expiry' do
      @txn_manager.set('k1', 'alpha')
      @txn_manager.set('k2', 'beta')
      @txn_manager.set('k3', 'gamma')

      heap = @txn_manager.instance_variable_get(:@expiry_heap)
      heap.each_with_index do |entry, i|
        next if i.zero?

        assert heap[0][0] <= entry[0],
               "heap root expiry #{heap[0][0]} should be <= heap[#{i}] expiry #{entry[0]}"
      end
    end

    it 'heap grows by one entry when same name is set again (renewal appends)' do
      @txn_manager.set('c', 'd') # seed an entry
      size_before = @txn_manager.instance_variable_get(:@expiry_heap).size
      @txn_manager.set('c', 'd') # renew existing name
      size_after = @txn_manager.instance_variable_get(:@expiry_heap).size
      _(size_after).must_equal size_before + 1
    end
  end

  describe 'purge_expired_entries' do
    it 'purge_expired_entries removes expired transaction names from pool' do
      past_expiry = Time.now.to_i - 10

      # Simulate an already-expired entry by overwriting state directly
      @txn_manager.instance_variable_get(:@transaction_name)['d'] = past_expiry
      @txn_manager.instance_variable_get(:@expiry_heap).clear
      @txn_manager.send(:heap_push, [past_expiry, 'd'])

      @txn_manager.send(:purge_expired_entries)

      assert_nil @txn_manager.instance_variable_get(:@transaction_name)['d']
      _(@txn_manager.instance_variable_get(:@expiry_heap)).must_be_empty
    end

    it 'purge_expired_entries leaves names whose expiry is still in the future' do
      future_expiry = Time.now.to_i + 60

      @txn_manager.instance_variable_get(:@transaction_name)['d'] = future_expiry
      @txn_manager.instance_variable_get(:@expiry_heap).clear
      @txn_manager.send(:heap_push, [future_expiry, 'd'])

      @txn_manager.send(:purge_expired_entries)

      _(@txn_manager.instance_variable_get(:@transaction_name)['d']).must_equal future_expiry
    end

    it 'renewal guard: stale heap entry does not evict a renewed transaction name' do
      stale_expiry = Time.now.to_i - 10
      fresh_expiry = Time.now.to_i + 60

      # Simulate renewal: @transaction_name holds new expiry, heap still has old entry
      @txn_manager.instance_variable_get(:@transaction_name)['d'] = fresh_expiry
      @txn_manager.instance_variable_get(:@expiry_heap).clear
      @txn_manager.send(:heap_push, [stale_expiry, 'd'])

      @txn_manager.send(:purge_expired_entries)

      # 'd' must survive because stored expiry (fresh) != stale heap entry's expiry
      _(@txn_manager.instance_variable_get(:@transaction_name)['d']).must_equal fresh_expiry
    end

    it 'purge_expired_entries stops at first non-expired entry (min-heap ordering)' do
      now = Time.now.to_i
      expired = now - 5
      future1 = now + 30
      future2 = now + 60

      txn_names = @txn_manager.instance_variable_get(:@transaction_name)
      txn_names['expired_a'] = expired
      txn_names['live_b']    = future1
      txn_names['live_c']    = future2

      @txn_manager.instance_variable_get(:@expiry_heap).clear
      @txn_manager.send(:heap_push, [expired, 'expired_a'])
      @txn_manager.send(:heap_push, [future1, 'live_b'])
      @txn_manager.send(:heap_push, [future2, 'live_c'])

      @txn_manager.send(:purge_expired_entries)

      assert_nil txn_names['expired_a']
      _(@txn_manager.instance_variable_get(:@transaction_name)['live_b']).must_equal future1
      _(@txn_manager.instance_variable_get(:@transaction_name)['live_c']).must_equal future2
    end
  end

  describe 'cleanup thread lifecycle' do
    it 'cleanup thread is started on first set and is alive' do
      @txn_manager.set('a', 'b')
      thread = @txn_manager.instance_variable_get(:@cleanup_thread)
      assert thread.alive?
    end

    it 'stop terminates the cleanup thread' do
      @txn_manager.set('a', 'b')
      thread = @txn_manager.instance_variable_get(:@cleanup_thread)
      assert thread.alive?

      @txn_manager.stop

      refute thread.alive?
    end

    it 'stop is idempotent and does not raise when called twice' do
      @txn_manager.stop
      assert @txn_manager.instance_variable_get(:@stopped)

      # A second stop should not raise even though the thread is already dead
      @txn_manager.stop
    end
  end
end
