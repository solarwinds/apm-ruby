// Copyright (c) 2019 SolarWinds, LLC.
// All rights reserved.

#include <iostream>

#ifdef __cplusplus
extern "C" {
#endif

void Init_oboe_metal(void);

void Init_libsolarwinds_apm() {
    Init_oboe_metal();
}

#ifdef __cplusplus
}
#endif
