# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'rails/railtie'
require_relative './load_swomarginalia'

module SolarWindsAPM
  module SWOMarginalia
    class Railtie < Rails::Railtie
      initializer 'swomarginalia.insert' do
        ActiveSupport.on_load :active_record do
          ::SolarWindsAPM::SWOMarginalia::LoadSWOMarginalia.insert_into_active_record
        end

        ActiveSupport.on_load :action_controller do
          ::SolarWindsAPM::SWOMarginalia::LoadSWOMarginalia.insert_into_action_controller
        end

        ActiveSupport.on_load :active_job do
          ::SolarWindsAPM::SWOMarginalia::LoadSWOMarginalia.insert_into_active_job
        end
      end
    end
  end
end