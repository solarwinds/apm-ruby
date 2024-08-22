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
          extracted_comments = sql.match(/\/\*\s*traceparent=?'?[0-9a-f]{2}-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}'?\s*\*\//)
          attributes = super(sql)
          attributes[::OpenTelemetry::SemanticConventions::Trace::DB_STATEMENT] = attributes[::OpenTelemetry::SemanticConventions::Trace::DB_STATEMENT] + extracted_comments&.match(0).to_s
          attributes
        else
          super(sql)
        end
      end
    end
  end
end

::Trilogy.prepend(SolarWindsAPM::Patches::SWOTrilogyClientPatch) if defined?(::Trilogy) && defined?(OpenTelemetry::Instrumentation::Trilogy::Patches::Client)	
