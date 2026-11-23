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

  # CI runs tests as root, so fake the owner/effective user instead of relying on real file ownership.
  def with_file_owner(path, uid, euid, &test_block)
    original_stat = File.method(:stat)
    owned_stat = SimpleDelegator.new(original_stat.call(path))
    owned_stat.define_singleton_method(:uid) { uid }
    stat_stub = ->(file) { file == path ? owned_stat : original_stat.call(file) }
    Process.stub(:euid, euid) { File.stub(:stat, stat_stub, &test_block) }
  end

  def untrusted_warning(path, reason)
    "[SolarWindsAPM::SecurePath/trusted?] The file #{path} is not trusted because #{reason}. " \
      'The file must be owned by root or by the user running the application, and neither the file nor its directory may be world-writable (e.g. file permission 600). ' \
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

  it 'trusts a file owned by the current user that is not world-writable' do
    assert SolarWindsAPM::SecurePath.trusted?(@file)
  end

  it 'rejects a world-writable file' do
    File.chmod(0o666, @file)

    warnings = capture_warnings { refute SolarWindsAPM::SecurePath.trusted?(@file) }

    assert_equal [untrusted_warning(@file, 'the file is world-writable')], warnings
  end

  it 'rejects a file in a world-writable non-sticky directory' do
    File.chmod(0o777, @dir)

    warnings = capture_warnings { refute SolarWindsAPM::SecurePath.trusted?(@file) }

    assert_equal [untrusted_warning(@file, 'its directory is world-writable')], warnings
  end

  it 'rejects a symlink whose target is in a world-writable non-sticky directory' do
    unsafe_dir = File.join(@tmpdir, 'unsafe').tap { |d| FileUtils.mkdir_p(d) }
    target = File.join(unsafe_dir, 'config.rb')
    File.write(target, "# config\n")
    File.chmod(0o644, target)
    File.chmod(0o777, unsafe_dir)
    link = File.join(@dir, 'link.rb')
    File.symlink(target, link)

    warnings = capture_warnings { refute SolarWindsAPM::SecurePath.trusted?(link) }

    assert_equal [untrusted_warning(link, 'its directory is world-writable')], warnings
  end

  it 'trusts a file in a world-writable sticky directory' do
    File.chmod(0o1777, @dir)

    assert SolarWindsAPM::SecurePath.trusted?(@file)
  end

  it 'rejects a file owned by a user other than root or the effective user' do
    warnings = capture_warnings do
      with_file_owner(@file, 4242, 1000) { refute SolarWindsAPM::SecurePath.trusted?(@file) }
    end

    assert_equal [untrusted_warning(@file, 'the file is owned by uid 4242, not by root or the effective user (uid 1000)')], warnings
  end

  it 'trusts a file owned by the effective user' do
    with_file_owner(@file, 1000, 1000) { assert SolarWindsAPM::SecurePath.trusted?(@file) }
  end

  it 'trusts a file owned by root' do
    with_file_owner(@file, 0, 1000) { assert SolarWindsAPM::SecurePath.trusted?(@file) }
  end

  it 'rejects a file that cannot be inspected' do
    missing = File.join(@dir, 'missing.rb')

    warnings = capture_warnings { refute SolarWindsAPM::SecurePath.trusted?(missing) }

    assert_equal ["[SolarWindsAPM::SecurePath/trusted?] Unable to inspect file #{missing}: No such file or directory @ rb_file_s_stat - #{missing}"], warnings
  end

  it 'skips permission checks on Windows' do
    File.chmod(0o666, @file)

    warnings = capture_warnings do
      Gem.stub(:win_platform?, true) { assert SolarWindsAPM::SecurePath.trusted?(@file) }
    end

    assert_empty warnings
  end
end
