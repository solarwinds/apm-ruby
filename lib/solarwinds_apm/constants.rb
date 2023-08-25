module SolarWindsAPM
  # Constants
  module Constants
    HTTP_METHOD      = "http.method".freeze
    HTTP_ROUTE       = "http.route".freeze
    HTTP_STATUS_CODE = "http.status_code".freeze
    HTTP_URL         = "http.url".freeze

    INTL_SWO_AO_COLLECTOR            = "collector.appoptics.com".freeze
    INTL_SWO_AO_STG_COLLECTOR        = "collector-stg.appoptics.com".freeze
    INTL_SWO_COMMA                   = ",".freeze
    INTL_SWO_COMMA_W3C_SANITIZED     = "....".freeze
    INTL_SWO_EQUALS                  = "=".freeze
    INTL_SWO_EQUALS_W3C_SANITIZED    = "####".freeze
    INTL_SWO_TRACESTATE_KEY          = "sw".freeze
    INTL_SWO_X_OPTIONS_KEY           = "sw_xtraceoptions".freeze
    INTL_SWO_SIGNATURE_KEY           = "sw_signature".freeze
    INTL_SWO_DEFAULT_TRACES_EXPORTER = "solarwinds_exporter".freeze
    INTL_SWO_TRACECONTEXT_PROPAGATOR = "tracecontext".freeze
    INTL_SWO_PROPAGATOR              = "solarwinds_propagator".freeze
    INTL_SWO_DEFAULT_PROPAGATORS     = [INTL_SWO_TRACECONTEXT_PROPAGATOR, "baggage",INTL_SWO_PROPAGATOR].freeze
    INTL_SWO_SUPPORT_EMAIL           = "SWO-support@solarwinds.com".freeze
    INTL_SWO_OTEL_SCOPE_NAME         = "otel.scope.name".freeze
    INTL_SWO_OTEL_SCOPE_VERSION      = "otel.scope.version".freeze

    INTERNAL_TRIGGERED_TRACE         = "TriggeredTrace".freeze
  end
end