# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  ##
  # The current version of the gem. Used mainly by
  # solarwinds_apm.gemspec during gem build process
  module Version
    MAJOR  = 7 # breaking,
    MINOR  = 1 # feature,
    PATCH  = 0 # fix => BFF
    PRE    = nil

    STRING = [MAJOR, MINOR, PATCH, PRE].compact.join('.')
  end
end
