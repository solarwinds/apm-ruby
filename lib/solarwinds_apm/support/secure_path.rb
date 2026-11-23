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
  # On POSIX systems, a file is untrusted if it is world-writable, is not owned by root or by the
  # effective user of this process, or lives in a world-writable directory without the sticky bit.
  # Permission checks are skipped on Windows, where POSIX permission bits are not meaningful.
  #
  module SecurePath
    ##
    # trusted?
    #
    # === Argument:
    #
    # * +path+ - Path of the file to verify
    #
    # === Example:
    #
    #   load(config_file) if SolarWindsAPM::SecurePath.trusted?(config_file)
    #
    # === Returns:
    # * Boolean - true if the file can be trusted; false otherwise (a warning with the reason is logged)
    #
    def self.trusted?(path)
      return true if Gem.win_platform?

      reason = untrusted_reason(path)
      return true unless reason

      SolarWindsAPM.logger.warn do
        "[#{name}/#{__method__}] The file #{path} is not trusted because #{reason}. " \
          'The file must be owned by root or by the user running the application, and neither the file nor its directory may be world-writable (e.g. file permission 600). ' \
          'Please change the ownership or permissions to make it secure.'
      end
      false
    rescue SystemCallError => e
      SolarWindsAPM.logger.warn { "[#{name}/#{__method__}] Unable to inspect file #{path}: #{e.message}" }
      false
    end

    def self.untrusted_reason(path)
      file_stat = File.stat(path)
      return 'the file is world-writable' if file_stat.world_writable?

      euid = Process.euid
      return "the file is owned by uid #{file_stat.uid}, not by root or the effective user (uid #{euid})" unless [0, euid].include?(file_stat.uid)

      # Check both the given directory and the symlink-resolved one.
      directories = [File.dirname(File.expand_path(path)), File.dirname(File.realpath(path))].uniq
      'its directory is world-writable' if directories.any? { |directory| insecure_directory?(directory) }
    end

    def self.insecure_directory?(directory)
      dir_stat = File.stat(directory)
      dir_stat.world_writable? && !dir_stat.sticky?
    end
    private_class_method :untrusted_reason, :insecure_directory?
  end
end
