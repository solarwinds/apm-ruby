For the latest release info, see here:
https://github.com/solarwindscloud/solarwinds-apm-ruby/releases

Dates in this file are in the format MM/DD/YYYY.

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
