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