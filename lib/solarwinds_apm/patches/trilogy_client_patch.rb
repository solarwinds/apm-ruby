# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

module SolarWindsAPM
  module Patches
    module SWOTrilogyClientPatch
      # this method is just save the traceparent comment before sanitization
      def client_attributes(sql = nil)
        if config[:db_statement] == :obfuscate
          extracted_comments = sql.match(TagSqlConstants::TRACEPARENT_REGEX)
          attributes = super
          attributes[::OpenTelemetry::SemanticConventions::Trace::DB_STATEMENT] = attributes[::OpenTelemetry::SemanticConventions::Trace::DB_STATEMENT] + extracted_comments&.match(0).to_s
          attributes
        else
          super
        end
      end
    end
  end
end

Trilogy.prepend(SolarWindsAPM::Patches::SWOTrilogyClientPatch) if defined?(Trilogy) && defined?(OpenTelemetry::Instrumentation::Trilogy::Patches::Client)
