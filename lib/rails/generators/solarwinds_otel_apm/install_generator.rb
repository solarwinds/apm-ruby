# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

module SolarWindsOTelAPM
  class InstallGenerator < ::Rails::Generators::Base
    source_root File.join(File.dirname(__FILE__), 'templates')
    desc "Copies a SolarWindsOTelAPM gem initializer file to your application."

    @namespace = "solarwinds_otel_apm:install"

    def copy_initializer
      # Set defaults
      @verbose = 'false'

      print_header
      print_footer

      template "solarwinds_otel_apm_initializer.rb", "config/initializers/solarwinds_otel_apm.rb"
    end

    private

    # rubocop:disable Metrics/MethodLength
    def print_header
      say ""
      say shell.set_color "Welcome to the SolarWindsOTelAPM Ruby instrumentation setup.", :green, :bold
      say ""
      say shell.set_color "Documentation Links", :magenta
      say "-------------------"
      say ""
      say "SolarWindsOTelAPM Installation Overview:"
      say "https://documentation.solarwinds.com/en/success_center/observability"
      say ""
      say "More information on instrumenting Ruby applications can be found here:"
      say "https://documentation.solarwinds.com/en/success_center/observability/default.htm#cshid=config-ruby-agent"
    end
    # rubocop:enable Metrics/MethodLength

    def print_footer
      say ""
      say "You can change configuration values in the future by modifying config/initializers/solarwinds_apm.rb"
      say ""
      say "Thanks! Creating the SolarWindsOTelAPM initializer..."
      say ""
    end
  end
end
