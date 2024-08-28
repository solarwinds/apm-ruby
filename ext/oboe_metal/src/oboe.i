%module oboe
%{
#include "oboe_api.h"
#include "oboe_debug.h"
%}
%include "stdint.i"
%include "std_string.i"

%newobject Metadata::copy;
%newobject Metadata::fromString;
%newobject Metadata::createEvent;
%newobject Metadata::makeRandom;

%newobject Context::startTrace;
%newobject Context::createEntry;
%newobject Context::createEvent;
%newobject Context::createExit;
%newobject Context::copy;

%newobject Event::startTrace;
%newobject Event::getMetadata;

%apply int *OUTPUT { int *do_metrics, int *do_sample, int *sample_rate, int *sample_source, int *type, int *auth, int *status};
%apply double *OUTPUT { double *bucket_rate, double *bucket_cap};
%apply std::string *OUTPUT { std::string *status_msg, std::string *auth_msg};
%apply unsigned int& OUTPUT { unsigned int& counter, unsigned int& rate, unsigned int& source };

%include "oboe_debug.h"
%include "oboe_api.h"
