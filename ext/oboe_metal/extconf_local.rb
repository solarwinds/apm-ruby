# frozen_string_literal: true

# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'mkmf'
require 'rbconfig'
require 'open-uri'

CONFIG['warnflags'] = CONFIG['warnflags'].gsub(/-Wdeclaration-after-statement/, '')
                                         .gsub(/-Wimplicit-function-declaration/, '')
                                         .gsub(/-Wimplicit-int/, '')
                                         .gsub(/-Wno-tautological-compare/, '')
                                         .gsub(/-Wno-self-assign/, '')
                                         .gsub(/-Wno-parentheses-equality/, '')
                                         .gsub(/-Wno-constant-logical-operand/, '')
                                         .gsub(/-Wno-cast-function-type/, '')
init_mkmf(CONFIG)

ext_dir = __dir__

# Set the mkmf lib paths so we have no issues linking to
# the SolarWindsAPM libs.
swo_lib_dir = File.join(ext_dir, 'lib')
swo_path = '../../../oboe/factory-output'
swo_clib = "liboboe-1.0-x86_64.so.0.0.0"
swo_item = File.join(swo_path, swo_clib)
clib = File.join(swo_lib_dir, swo_clib)

FileUtils.cp(swo_item, clib)

# Create relative symlinks for the SolarWindsAPM library
Dir.chdir(swo_lib_dir) do
  File.symlink(swo_clib, 'liboboe.so')
  File.symlink(swo_clib, 'liboboe-1.0.so.0')
end

dir_config('oboe', 'src', 'lib')

if have_library('oboe', 'oboe_config_get_revision', 'oboe.h')
  $libs = append_library($libs, 'oboe')
  $libs = append_library($libs, 'stdc++')

  $CFLAGS << " #{ENV['CFLAGS']}"
  # $CPPFLAGS << " #{ENV['CPPFLAGS']} -std=c++11"
  # TODO for debugging: -pg -gdwarf-2, remove for production
  # -pg does not work on alpine https://www.openwall.com/lists/musl/2014/11/05/2
  $CPPFLAGS << " #{ENV['CPPFLAGS']} -std=c++11  -gdwarf-2 -I$$ORIGIN/../ext/oboe_metal/include -I$$ORIGIN/../ext/oboe_metal/src"
  # $CPPFLAGS << " #{ENV['CPPFLAGS']} -std=c++11 -I$$ORIGIN/../ext/oboe_metal/include"
  $LIBS << " #{ENV['LIBS']}"

  # use "z,defs" to see what happens during linking
  # $LDFLAGS << " #{ENV['LDFLAGS']} '-Wl,-rpath=$$ORIGIN/../ext/oboe_metal/lib,-z,defs'  -lrt"
  $LDFLAGS << " #{ENV['LDFLAGS']} '-Wl,-rpath=$$ORIGIN/../ext/oboe_metal/lib' -lrt"
  $CXXFLAGS += " -std=c++11 "

  # ____ include debug info, comment out when not debugging
  # ____ -pg -> profiling info for gprof
  CONFIG["debugflags"] = "-ggdb3 "
  CONFIG["optflags"] = "-O0"

  create_makefile('libsolarwinds_apm', 'src')
else
  $stderr.puts '== ERROR ========================================================='
  if have_library('oboe')
    $stderr.puts "The c-library either needs to be updated or doesn't match the OS."
    $stderr.puts 'No tracing will occur.'
  else
    $stderr.puts 'Could not find a matching c-library. No tracing will occur.'
  end
  $stderr.puts 'Contact technicalsupport@solarwinds.com if the problem persists.'
  $stderr.puts '=================================================================='
  create_makefile('oboe_noop', 'noop')
end
