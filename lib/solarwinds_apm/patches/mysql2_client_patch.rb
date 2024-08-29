# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

module SolarWindsAPM
  module Patches
    module SWOMysql2ClientPatch
      # this method is just save the traceparent comment before sanitization
      def _otel_span_attributes(sql)
        # if omit, then no need to append any statement
        # if include, then comments won't be removed
        # only obfuscate need to add the original comments back
        #   because of obfuscation method removed the comments
        # This module need to injected after Mysql2::Patches::Client prepended (aka after solarwinds_apm initialized)
        # check ::Mysql2::Client.included_modules or ::Mysql2::Client.ancestors to see the order of calling
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

Mysql2::Client.prepend(SolarWindsAPM::Patches::SWOMysql2ClientPatch) if defined?(Mysql2::Client) && defined?(OpenTelemetry::Instrumentation::Mysql2::Patches::Client)
