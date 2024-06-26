# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

####
# noop version of SolarWindsAPM::Span
#
module Oboe_metal # rubocop:disable Naming/ClassAndModuleCamelCase
  # Span
  class Span
    ##
    # noop version of :createHttpSpan
    #
    def self.createHttpSpan(*); end

    ##
    # noop version of :createSpan
    #
    def self.createSpan(*); end
  end
end
