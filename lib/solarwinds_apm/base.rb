# # © 2023 SolarWinds Worldwide, LLC. All rights reserved.
# #
# # Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
# #
# # Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

# module SolarWindsAPM
#   ##
#   # Provides thread local storage for SolarWindsAPM.
#   #
#   module ThreadLocal
#     def thread_local(name)
#       key = "__#{self}_#{name}__".intern

#       define_method(name) do
#         Thread.current[key]
#       end

#       define_method("#{name}=") do |value|
#         Thread.current[key] = value
#       end
#     end
#   end
# end

# ##
# # This module is the base module for SolarWindsAPM reporting.
# #
# module SolarWindsAPMBase
#   extend SolarWindsAPM::ThreadLocal

#   attr_accessor :reporter, :loaded
# end

# module SolarWindsAPM
#   extend SolarWindsAPMBase
# end

# # Setup an alias
# SolarWindsApm = SolarWindsAPM
# SolarwindsApm = SolarWindsAPM
# SolarwindsAPM = SolarWindsAPM
# Solarwindsapm = SolarWindsAPM
