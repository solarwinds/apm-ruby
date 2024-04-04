#include <stdio.h>
#include "ruby.h"

#ifdef __cplusplus
extern "C" {
#endif

VALUE method_hello(VALUE self) {
    return rb_str_new2("Hello from Oboe_metal!");
}

static VALUE example_initialize(VALUE self) {
    rb_iv_set(self, "@initialized", Qtrue); // Example of initializing an instance variable
    return self; // Conventionally, return the object itself
}

void Init_oboe_metal(){
    VALUE OboeMetal = rb_define_module("Oboe_metal");
    rb_define_method(OboeMetal, "hello", method_hello, 0);
    VALUE ExampleClass = rb_define_class_under(OboeMetal, "Reporter", rb_cObject);
    rb_define_method(ExampleClass, "initialize", example_initialize, 1);
}

void Init_libsolarwinds_apm() {
    Init_oboe_metal();
}

#ifdef __cplusplus
}
#endif
