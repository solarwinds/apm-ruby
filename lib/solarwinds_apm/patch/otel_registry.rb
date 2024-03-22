# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

module SolarWindsAPM
  module Patch
    module OtelRegistry
      def install_instrumentation(instrumentation, config)
        if !instrumentation.present?
          ::OpenTelemetry.logger.debug "Instrumentation: #{instrumentation.name} skipping install given corresponding dependency not found"
        elsif instrumentation.install(config)
          ::OpenTelemetry.logger.info "Instrumentation: #{instrumentation.name} was successfully installed with the following options #{instrumentation.config}"
        else
          ::OpenTelemetry.logger.warn "Instrumentation: #{instrumentation.name} failed to install"
        end
      rescue => e # rubocop:disable Style/RescueStandardError
        ::OpenTelemetry.handle_error(exception: e, message: "Instrumentation: #{instrumentation.name} unhandled exception during install: #{e.backtrace}")
      end
    end
  end
end
