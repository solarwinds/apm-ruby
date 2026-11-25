# frozen_string_literal: true

# Copyright (c) 2026 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'tmpdir'
require 'fileutils'
require 'delegate'
require './lib/solarwinds_apm/support/secure_path'

describe 'SolarWindsAPM::SecurePath' do
  def capture_warnings(&test_block)
    warnings = []
    SolarWindsAPM.logger.stub(:warn, ->(message = nil, &block) { warnings << (block ? block.call : message) }, &test_block)
    warnings
  end

  # CI runs tests as root, so fake the owner of the given paths instead of relying on real file ownership.
  def with_owners(uids_by_path, &test_block)
    original_lstat = File.method(:lstat)
    lstat_stub = lambda do |file|
      stat = original_lstat.call(file)
      return stat unless uids_by_path.key?(file)

      SimpleDelegator.new(stat).tap { |owned_stat| owned_stat.define_singleton_method(:uid) { uids_by_path[file] } }
    end
    File.stub(:lstat, lstat_stub, &test_block)
  end

  def untrusted_warning(path, reason)
    "[SolarWindsAPM::SecurePath/trusted_path] The file #{path} is not trusted because #{reason}. " \
      'The file and every directory in its path must be owned by root or by the user running the application, ' \
      'the file must not be world-writable (e.g. file permission 600), and the directories must not be world-writable unless they have the sticky bit. ' \
      'Please change the ownership or permissions to make it secure.'
  end

  before do
    @tmpdir = File.realpath(Dir.mktmpdir('sw_apm_secure_path'))
    @dir    = File.join(@tmpdir, 'secure').tap { |d| FileUtils.mkdir_p(d) }
    @file   = File.join(@dir, 'config.rb')
    File.write(@file, "# config\n")
    File.chmod(0o644, @file)
  end

  after do
    FileUtils.rm_rf(@tmpdir)
  end

  it 'returns the path of a file owned by the current user that is not world-writable' do
    assert_equal @file, SolarWindsAPM::SecurePath.trusted_path(@file)
  end

  it 'returns the resolved target of a symlink so that the link cannot be retargeted before loading' do
    shared_dir = File.join(@tmpdir, 'shared').tap { |d| FileUtils.mkdir_p(d) }
    File.chmod(0o1777, shared_dir)
    link = File.join(shared_dir, 'link.rb')
    File.symlink(@file, link)

    with_owners(link => 4242) { assert_equal @file, SolarWindsAPM::SecurePath.trusted_path(link) }
  end

  it 'rejects a world-writable file' do
    File.chmod(0o666, @file)

    warnings = capture_warnings { assert_nil SolarWindsAPM::SecurePath.trusted_path(@file) }

    assert_equal [untrusted_warning(@file, 'the file is world-writable')], warnings
  end

  it 'rejects a file in a world-writable non-sticky directory' do
    File.chmod(0o777, @dir)

    warnings = capture_warnings { assert_nil SolarWindsAPM::SecurePath.trusted_path(@file) }

    assert_equal [untrusted_warning(@file, "directory #{@dir} is world-writable")], warnings
  end

  it 'rejects a file below a world-writable non-sticky ancestor directory' do
    File.chmod(0o777, @tmpdir)

    warnings = capture_warnings { assert_nil SolarWindsAPM::SecurePath.trusted_path(@file) }

    assert_equal [untrusted_warning(@file, "directory #{@tmpdir} is world-writable")], warnings
  end

  it 'rejects a symlink whose target is in a world-writable non-sticky directory' do
    unsafe_dir = File.join(@tmpdir, 'unsafe').tap { |d| FileUtils.mkdir_p(d) }
    target = File.join(unsafe_dir, 'config.rb')
    File.write(target, "# config\n")
    File.chmod(0o644, target)
    File.chmod(0o777, unsafe_dir)
    link = File.join(@dir, 'link.rb')
    File.symlink(target, link)

    warnings = capture_warnings { assert_nil SolarWindsAPM::SecurePath.trusted_path(link) }

    assert_equal [untrusted_warning(link, "directory #{unsafe_dir} is world-writable")], warnings
  end

  it 'trusts a file in a world-writable sticky directory' do
    File.chmod(0o1777, @dir)

    assert_equal @file, SolarWindsAPM::SecurePath.trusted_path(@file)
  end

  it 'rejects a file owned by a user other than root or the effective user' do
    warnings = capture_warnings do
      with_owners(@file => 4242) { assert_nil SolarWindsAPM::SecurePath.trusted_path(@file) }
    end

    assert_equal [untrusted_warning(@file, "the file #{@file} is owned by uid 4242, not by root or the effective user (uid #{Process.euid})")], warnings
  end

  it 'rejects a file in a directory owned by a user other than root or the effective user' do
    warnings = capture_warnings do
      with_owners(@dir => 4242) { assert_nil SolarWindsAPM::SecurePath.trusted_path(@file) }
    end

    assert_equal [untrusted_warning(@file, "directory #{@dir} is owned by uid 4242, not by root or the effective user (uid #{Process.euid})")], warnings
  end

  it 'rejects a file in a world-writable sticky directory owned by another user' do
    File.chmod(0o1777, @dir)

    warnings = capture_warnings do
      with_owners(@dir => 4242) { assert_nil SolarWindsAPM::SecurePath.trusted_path(@file) }
    end

    assert_equal [untrusted_warning(@file, "directory #{@dir} is owned by uid 4242, not by root or the effective user (uid #{Process.euid})")], warnings
  end

  it 'trusts a file owned by root' do
    with_owners(@file => 0) { assert_equal @file, SolarWindsAPM::SecurePath.trusted_path(@file) }
  end

  it 'rejects a file that cannot be inspected' do
    missing = File.join(@dir, 'missing.rb')

    warnings = capture_warnings { assert_nil SolarWindsAPM::SecurePath.trusted_path(missing) }

    assert_equal 1, warnings.size
    assert_match(%r{\A\[SolarWindsAPM::SecurePath/trusted_path\] Unable to inspect file #{Regexp.escape(missing)}: No such file or directory}, warnings.first)
  end

  it 'skips permission checks on Windows' do
    File.chmod(0o666, @file)

    warnings = capture_warnings do
      Gem.stub(:win_platform?, true) { assert_equal @file, SolarWindsAPM::SecurePath.trusted_path(@file) }
    end

    assert_empty warnings
  end
end
