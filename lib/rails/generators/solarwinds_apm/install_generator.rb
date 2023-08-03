# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

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
