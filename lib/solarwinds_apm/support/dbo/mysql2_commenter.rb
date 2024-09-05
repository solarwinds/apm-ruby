# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  module Dbo
    module Mysql2Commenter
      def query(sql, options = {})
        sql = Comment.annotate_sql(sql) # we annotate here, without help of activerecord + marginalia
        super                           # this super calls instrumentation prepend, so we still need to bypass the obfuscation restriction
      end

      def prepare(sql)
        sql = Comment.annotate_sql(sql)
        super
      end

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

Mysql2::Client.prepend(SolarWindsAPM::Dbo::Mysql2Commenter) if defined?(Mysql2::Client) && defined?(OpenTelemetry::Instrumentation::Mysql2::Patches::Client)
