# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

####
# noop version of SolarWindsAPM::Context
#
# module SolarWindsAPM
# end

module Oboe_metal # rubocop:disable Naming/ClassAndModuleCamelCase
  # Context for noop
  class Context
    ##
    # noop version of :toString
    # toString would return the current trace context as string
    #
    def self.toString
      '99-00000000000000000000000000000000-0000000000000000-00'
    end

    def self.isReady(*)
      false
    end

    def self.getDecisions(*)
      [-1, -1, -1, 0, 0.0, 0.0, -1, -1, '', '', 4]
    end

    ##
    # noop version of :clear
    #
    def self.clear; end
  end
end
