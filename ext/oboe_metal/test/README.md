C-code tests:

CMakeLists.txt includes downloading and compiling googletest if necessary

In the ext/oboe_metal/test directory:

Set an environment variable for the current path:
```
export TEST_DIR=`pwd`
```

Every time the ruby version changes the solarwinds_apm gem needs to be 
re-installed or its c++-code recompiled and relinked

These environment variables need to be set every time the ruby version is set:
```
export RUBY_INC_DIR=$(ruby ruby_inc_dir.rb)
export RUBY_PREFIX=$(ruby ruby_prefix.rb)
```

create the Makefile (needs to be remade when the ruby version changes)
```
cmake -S . -B build
```
build
```
cmake --build build
```
run 
```
cd build && ctest && cd -
```

TODO:

- write a script for this

```
export TEST_DIR=`pwd`
export RUBY_INC_DIR=$(ruby ruby_inc_dir.rb)
export RUBY_PREFIX=$(ruby ruby_prefix.rb)
cmake -S . -B build
cmake --build build
cd build && ctest && cd -
```