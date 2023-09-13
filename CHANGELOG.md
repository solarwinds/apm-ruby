For the latest release info, see here:
https://github.com/solarwindscloud/solarwinds-apm-ruby/releases

Dates in this file are in the format MM/DD/YYYY.


# solarwinds_apm 6.0.0.preV3 (08/08/2023)

This release includes the following features:

* Updgraded liboboe version to 13.0.0
* Rescue the sampler, processor and exporter without re-raise the error
* Marginlia for tracecontext in sql will work for activerecord > 7 with non-rails app (e.g. sinatra)
* Environmental variable name change: SOLARWINDS_APM_ENABLED -> SW_APM_ENABLED
* Updated lumberjack for tracecontext in logs
* Refactored test file structure based on folder `lib/`
* DB statement obfuscate for mysql2, pg and dalli will be default for opentelemetry-instrumentation
* Added otel.status and otel.description in span attributes
* Abandoned baggage to store root span; instea, using txn_manager
* Changed layer to span.kind:span.name
* Removed extensions from transaction_settings

# solarwinds_apm 6.0.0.preV2 (08/08/2023)

This release includes the following features:

* Start to use `http.target` as the path for transaction filtering
* Refactored the test strategy that avoid compiling liboboe extension while testing
* Updated the rake task that start up the docker container for both test and development
* Unsupport tracecontext in sql for non-rails app with activerecord > 7
* Updated README.md, CONTRIBUTING.md and CONFIG.md

# solarwinds_apm 6.0.0.preV1 (06/16/2023)

This release includes the following features:

* Alpha (preV1) release
* Integrate opentelemetry-ruby into solarwinds ruby library that adopt opentelemetry trace and span convention
