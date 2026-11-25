# frozen_string_literal: true

# © 2026 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  ##
  # SecurePath
  #
  # Verifies that a file is safe to execute (e.g. load as Ruby code) with the application's privileges.
  #
  # On POSIX systems, the path is resolved to its real path (no symlinks) first. The file is untrusted if
  # it is world-writable or is not owned by root or by the effective user of this process. Every directory
  # of the real path, up to the filesystem root, must also be owned by root or by the effective user, and
  # must not be world-writable unless it has the sticky bit.
  #
  # Callers must use the returned real path rather than the original one: no untrusted user can modify
  # any component of the validated real path, whereas a symlink in the original path could be retargeted
  # after validation.
  #
  # Permission checks are skipped on Windows, where POSIX permission bits are not meaningful.
  #
  module SecurePath
    ##
    # trusted_path
    #
    # === Argument:
    #
    # * +path+ - Path of the file to verify
    #
    # === Example:
    #
    #   trusted_file = SolarWindsAPM::SecurePath.trusted_path(config_file)
    #   load(trusted_file) if trusted_file
    #
    # === Returns:
    # * String - the validated real path of the file (the given path on Windows)
    # * nil - if the file can't be trusted (a warning with the reason is logged)
    #
    def self.trusted_path(path)
      return path if Gem.win_platform?

      real_path = File.realpath(path)
      reason = file_untrusted_reason(real_path) || directory_untrusted_reason(File.dirname(real_path))
      return real_path unless reason

      SolarWindsAPM.logger.warn do
        "[#{name}/#{__method__}] The file #{path} is not trusted because #{reason}. " \
          'The file and every directory in its path must be owned by root or by the user running the application, ' \
          'the file must not be world-writable (e.g. file permission 600), and the directories must not be world-writable unless they have the sticky bit. ' \
          'Please change the ownership or permissions to make it secure.'
      end
      nil
    rescue SystemCallError => e
      SolarWindsAPM.logger.warn { "[#{name}/#{__method__}] Unable to inspect file #{path}: #{e.message}" }
      nil
    end

    def self.file_untrusted_reason(real_path)
      file_stat = File.lstat(real_path)
      return 'the file is world-writable' if file_stat.world_writable?

      owner_untrusted_reason("the file #{real_path}", file_stat)
    end

    # Walks up to the filesystem root; any untrusted ancestor could rename or replace the entries below it.
    def self.directory_untrusted_reason(directory)
      loop do
        dir_stat = File.lstat(directory)
        reason = owner_untrusted_reason("directory #{directory}", dir_stat)
        return reason if reason
        return "directory #{directory} is world-writable" if dir_stat.world_writable? && !dir_stat.sticky?

        parent = File.dirname(directory)
        return nil if parent == directory

        directory = parent
      end
    end

    def self.owner_untrusted_reason(subject, stat)
      euid = Process.euid
      return if [0, euid].include?(stat.uid)

      "#{subject} is owned by uid #{stat.uid}, not by root or the effective user (uid #{euid})"
    end
    private_class_method :file_untrusted_reason, :directory_untrusted_reason, :owner_untrusted_reason
  end
end
