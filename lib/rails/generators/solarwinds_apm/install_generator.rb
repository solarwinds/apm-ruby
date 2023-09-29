# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  # InstallGenerator
  class InstallGenerator < ::Rails::Generators::Base
    source_root File.join(File.dirname(__FILE__), 'templates')
    desc "Copies a SolarWindsAPM gem initializer file to your application."

    @namespace = "solarwinds_apm:install"

    def copy_initializer
      print_header
      print_footer

      template "solarwinds_apm_initializer.rb", "config/initializers/solarwinds_apm.rb"
    end

    private

    def print_header
      say ""
      say shell.set_color "Welcome to the SolarWindsAPM Ruby instrumentation setup.", :green, :bold
      say ""
      say shell.set_color "Documentation Links", :magenta
      say "-------------------"
      say ""
      say "SolarWindsAPM Installation Overview:"
      say "https://documentation.solarwinds.com/en/success_center/observability"
      say ""
      say "More information on instrumenting Ruby applications can be found here:"
      say "https://documentation.solarwinds.com/en/success_center/observability/default.htm#cshid=config-ruby-agent"
    end

    def print_footer
      say ""
      say "You can change configuration values in the future by modifying config/initializers/solarwinds_apm.rb"
      say ""
      say "Thanks! Creating the SolarWindsAPM initializer..."
      say ""
    end
  end
end
