# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

module SolarWindsAPM
  # Constants
  module Constants
    HTTP_METHOD                      = 'http.method'
    HTTP_ROUTE                       = 'http.route'
    HTTP_STATUS_CODE                 = 'http.status_code'
    HTTP_URL                         = 'http.url'
    INTL_SWO_AO_COLLECTOR            = 'collector.appoptics.com'
    INTL_SWO_AO_STG_COLLECTOR        = 'collector-stg.appoptics.com'
    INTL_SWO_COMMA                   = ','
    INTL_SWO_COMMA_W3C_SANITIZED     = '....'
    INTL_SWO_EQUALS                  = '='
    INTL_SWO_EQUALS_W3C_SANITIZED    = '####'
    INTL_SWO_TRACESTATE_KEY          = 'sw'
    INTL_SWO_X_OPTIONS_KEY           = 'sw_xtraceoptions'
    INTL_SWO_SIGNATURE_KEY           = 'sw_signature'
    INTL_SWO_DEFAULT_TRACES_EXPORTER = 'solarwinds_exporter'
    INTL_SWO_TRACECONTEXT_PROPAGATOR = 'tracecontext'
    INTL_SWO_PROPAGATOR              = 'solarwinds_propagator'
    INTL_SWO_DEFAULT_PROPAGATORS     = [INTL_SWO_TRACECONTEXT_PROPAGATOR, 'baggage', INTL_SWO_PROPAGATOR].freeze
    INTL_SWO_SUPPORT_EMAIL           = 'SWO-support@solarwinds.com'
    INTL_SWO_OTEL_SCOPE_NAME         = 'otel.scope.name'
    INTL_SWO_OTEL_SCOPE_VERSION      = 'otel.scope.version'
    INTL_SWO_OTEL_STATUS             = 'otel.status_code'
    INTL_SWO_OTEL_STATUS_DESCRIPTION = 'otel.status_description'
    INTERNAL_TRIGGERED_TRACE         = 'TriggeredTrace'
  end
end
