# Changelog

For the latest release info, see here:
<https://github.com/solarwinds/apm-ruby/releases>

Dates in this file are in the format MM/DD/YYYY.

## solarwinds_apm 6.1.2 (02/28/2025)

This release includes the following features:

* `add_tracer` helper function for custom instrumentation on specific function
* Added dbo integration for PostgreSQL (without prepared statement)

## solarwinds_apm 6.1.1 (12/09/2024)

This release includes the following features:

* Mysql2 sqlcommenting for DBO integration
* Removed the marginalia support on query commenting
* Added the support of after fork on forked process

## solarwinds_apm 6.1.0 (09/18/2024)

This release includes the following features:

* NH-85975: update lambda layer log
* Lambda response mag
* NH-86570: add swomarginalia support to rails 7~7.1 regard to format
* Lambda build with checkout
* Loosen token validation
* NH-88760: add markdown lint and link
* NH-65373: add SW_APM_TRANSACTION_NAME to configuration.md
* Reference upstream docs on instrumentation env vars
* NH-85973 NH-89212 instrument function handler dependencies
* NH-89340: add ci/cd for reverse lab scan
* NH-89715 update trace attribute otel.status to otel.status_code
* NH-89340 remove json dependency
* NH-89212 use upstream exporter
* NH-89983: remove doc/ from lambda build; fix logging
* NH-90728: update workflow for both stg and prod lambda
* NH-90728 show whether publishing to staging or production
* NH-89340: add scan as part of build and publish lambda layer
* NH-89406: improve control for building debug version of the extension and added documentation
* Bump DavidAnson/markdownlint-cli2-action from 16 to 17
* NH-91517 only set response time HTTP attrs for HTTP server entry spans

## solarwinds_apm 6.0.2 (06/27/2024)

This release includes the following features:

* Add multi-runtime lambda layer
* Fix the issue of init msg not sent

## solarwinds_apm 6.0.1 (06/20/2024)

This release includes the following features:

* Documentation update.
* Reduce the length pf rubocop config file.
* Oboe version update to 15.0.1.

## solarwinds_apm 6.0.0 (04/11/2024)

This release includes the following features:

* First official apm-ruby release.
* Add lambda layer workflow.
* Refactor on logging when service key is invalid.
* Using noop for all possible error from our agent.

## solarwinds_apm 6.0.0.prev6 (01/30/2024)

This release includes the following features:

* Updated release process and documentation.
* Added custom metrics information to README.
* Integrated rubocop-performance for code optimization.
* Replace Packagecloud with GitHub package.
* Removed database obfuscation logic set from SolarWinds side.
* Changed trigger_tracing_mode to symbol.
* Added dependabot.yml for automated dependency updates.
* Ensured reporter starts regardless of worker or master status.
* Upgraded to version 14.0.1.
* Synchronized SolarWinds logger with OpenTelemetry logger.
* Updated versioning and workflow for Amazon Linux 2 on checkout.
* Dependency updates by Dependabot.

## solarwinds_apm 6.0.0.preV5 (11/06/2023)

This release includes the following features:

* Update README, CONFIGURATION and CODEOWNERS
* Add license header for src file
* Enable returning digit from `solarwinds_ready?`
* Repo name update and archive the old repo
* Enable `SW_APM_TRANSACTION_NAME` env variable for setting transaction name
* Bug fix on determining the service_name from oboe_init
* Backward compatibility of custom metrics in [#74](https://github.com/solarwinds/apm-ruby/pull/74)

## solarwinds_apm 6.0.0.preV4 (09/14/2023)

This release includes the following features:

* Relaxed the opentelemetry-sdk version requirement to 1.2.0 for common version 0.19.6

## solarwinds_apm 6.0.0.preV3 (09/13/2023)

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

## solarwinds_apm 6.0.0.preV2 (08/08/2023)

This release includes the following features:

* Start to use `http.target` as the path for transaction filtering
* Refactored the test strategy that avoid compiling liboboe extension while testing
* Updated the rake task that start up the docker container for both test and development
* Unsupport tracecontext in sql for non-rails app with activerecord > 7
* Updated README.md, CONTRIBUTING.md and CONFIG.md

## solarwinds_apm 6.0.0.preV1 (06/16/2023)

This release includes the following features:

* Alpha (preV1) release
* Integrate opentelemetry-ruby into solarwinds ruby library that adopt opentelemetry trace and span convention
