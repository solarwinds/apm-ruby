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
swo_include = File.join(ext_dir, 'src')

# Download the appropriate liboboe from Staging or Production
version = File.read(File.join(swo_include, 'VERSION')).strip
if ENV['OBOE_DEV'].to_s.casecmp('true').zero?
  swo_path = "https://solarwinds-apm-staging.s3.us-west-2.amazonaws.com/apm/c-lib/nightly"
  puts 'Fetching c-lib from DEVELOPMENT Build'
elsif ENV['OBOE_STAGING'].to_s.casecmp('true').zero?
  swo_path = File.join('https://agent-binaries.global.st-ssp.solarwinds.com/apm/c-lib/', version)
  puts 'Fetching c-lib from STAGING'
else
  swo_path = File.join('https://agent-binaries.cloud.solarwinds.com/apm/c-lib/', version)
end

swo_arch = 'x86_64'
system_arch = `uname -m` # for mac, the command is `uname` # "Darwin\n"; try `uname -a`
system_arch.delete!("\n")
case system_arch
when 'x86_64'
  swo_arch = 'x86_64'
when 'aarch64'
  swo_arch = 'aarch64'
end

if File.exist?('/etc/alpine-release')
  version = File.read('/etc/alpine-release').strip

  tmp_swo_arch = swo_arch.clone
  swo_arch =
    if Gem::Version.new(version) < Gem::Version.new('3.9')
      "alpine-libressl-#{tmp_swo_arch}"
    else # openssl
      "alpine-#{tmp_swo_arch}"
    end
end

swo_clib = "liboboe-1.0-#{swo_arch}.so"
swo_clib = "liboboe-1.0-lambda-#{swo_arch}.so" if ENV['LAMBDA_TASK_ROOT'] || ENV['AWS_LAMBDA_FUNCTION_NAME']
swo_item = File.join(swo_path, swo_clib)
swo_checksum_file = File.join(swo_lib_dir, "#{swo_clib}.sha256")
clib = File.join(swo_lib_dir, swo_clib)

retries = 3
success = false
while retries > 0
  begin
    IO.copy_stream(URI.parse(swo_item).open, clib)
    clib_checksum = Digest::SHA256.file(clib).hexdigest
    checksum      =  File.read(swo_checksum_file).strip

    # unfortunately these messages only show if the install command is run
    # with the `--verbose` flag
    if clib_checksum != checksum
      $stderr.puts '== ERROR ================================================================='
      $stderr.puts 'Checksum Verification failed for the c-extension of the solarwinds_apm gem'
      $stderr.puts 'Installation cannot continue'
      $stderr.puts "\nChecksum packaged with gem:   #{checksum}"
      $stderr.puts "Checksum calculated from lib: #{clib_checksum}"
      $stderr.puts 'Contact technicalsupport@solarwinds.com if the problem persists'
      $stderr.puts '=========================================================================='
      exit 1
    else
      success = true
      retries = 0
    end
  rescue StandardError => e
    File.write(clib, '')
    retries -= 1
    if retries == 0
      $stderr.puts '== ERROR =========================================================='
      $stderr.puts 'Download of the c-extension for the solarwinds_apm gem failed.'
      $stderr.puts 'solarwinds_apm will not instrument the code. No tracing will occur.'
      $stderr.puts 'Contact technicalsupport@solarwinds.com if the problem persists.'
      $stderr.puts "error: #{swo_item}\n#{e.message}"
      $stderr.puts '==================================================================='
      create_makefile('oboe_noop', 'noop')
    end
    sleep 0.5
  end
end

if success
  # Create relative symlinks for the SolarWindsAPM library
  Dir.chdir(swo_lib_dir) do
    File.symlink(swo_clib, 'liboboe.so')
    File.symlink(swo_clib, 'liboboe-1.0.so.0')
  end

  dir_config('oboe', 'src', 'lib')

  # create Makefile
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
end