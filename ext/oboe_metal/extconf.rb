# frozen_string_literal: true

# Copyright (c) 2016 SolarWinds, LLC.
# All rights reserved.

require 'mkmf'
require 'rbconfig'
require 'open-uri'

CONFIG['warnflags'] = CONFIG['warnflags'].gsub('-Wdeclaration-after-statement', '')
                                         .gsub('-Wimplicit-function-declaration', '')
                                         .gsub('-Wimplicit-int', '')
                                         .gsub('-Wno-tautological-compare', '')
                                         .gsub('-Wno-self-assign', '')
                                         .gsub('-Wno-parentheses-equality', '')
                                         .gsub('-Wno-constant-logical-operand', '')
                                         .gsub('-Wno-cast-function-type', '')
init_mkmf(CONFIG)

ext_dir = __dir__
ENV['OBOE_DEBUG'].to_s.casecmp('true').zero?
oboe_env = ENV.fetch('OBOE_ENV', nil)
non_production = %w[dev stg].include? oboe_env.to_s

swo_lib_dir = File.join(ext_dir, 'lib')
version     = File.read(File.join(ext_dir, 'src', 'VERSION')).strip

case oboe_env
when 'dev'
  swo_path = 'https://solarwinds-apm-staging.s3.us-west-2.amazonaws.com/apm/c-lib/nightly'
  puts 'Fetching c-lib from DEVELOPMENT Build'
when 'stg'
  swo_path = File.join('https://agent-binaries.global.st-ssp.solarwinds.com/apm/c-lib/', version)
  puts 'Fetching c-lib from STAGING Build'
else
  swo_path = File.join('https://agent-binaries.cloud.solarwinds.com/apm/c-lib/', version)
  puts 'Fetching c-lib from PRODUCTION Build'
end

oboe_debug = ENV['OBOE_DEBUG'].to_s.casecmp('true').zero?

if oboe_debug
  swo_path = File.join(swo_path, 'relwithdebinfo')
  puts "Fetching DEBUG Build based on #{oboe_env.to_s.empty? ? 'prod' : oboe_env}"
end

puts "final swo_path: #{swo_path}"

swo_arch = 'x86_64'
system_arch = `uname -m` # for mac, the command is `uname` # "Darwin\n"; try `uname -a`
system_arch.delete!("\n")
case system_arch
when 'x86_64'
  swo_arch = 'x86_64'
when 'aarch64' || 'arm64'
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
while retries.positive?
  begin
    IO.copy_stream(URI.parse(swo_item).open, clib)
    clib_checksum = Digest::SHA256.file(clib).hexdigest
    checksum      = File.read(swo_checksum_file).strip

    # sha256 always from prod, so no matching for stg or nightly build or debug mode
    # so ignore the sha comparsion when fetching from development and staging build
    checksum = clib_checksum if non_production || oboe_debug

    # unfortunately these messages only show if the install command is run
    # with the `--verbose` flag
    if clib_checksum == checksum
      success = true
    else
      puts 'Checksum Verification Fail' # this is mainly for testing
      warn '== ERROR ================================================================='
      warn 'Checksum Verification failed for the c-extension of the solarwinds_apm gem'
      warn 'Installation cannot continue'
      warn "\nChecksum packaged with gem:   #{checksum}"
      warn "Checksum calculated from lib: #{clib_checksum}"
      warn 'Contact technicalsupport@solarwinds.com if the problem persists'
      warn '=========================================================================='
    end
    retries = 0
  rescue StandardError => e
    File.write(clib, '')
    retries -= 1
    if retries.zero?
      warn '== ERROR =========================================================='
      warn 'Download of the c-extension for the solarwinds_apm gem failed.'
      warn 'solarwinds_apm will not instrument the code. No tracing will occur.'
      warn 'Contact technicalsupport@solarwinds.com if the problem persists.'
      warn "error: #{swo_item}\n#{e.message}"
      warn '==================================================================='
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

    $CFLAGS << " #{ENV.fetch('CFLAGS', nil)}"

    # -pg option is used for generating profiling information with gprof
    $CPPFLAGS << if oboe_debug
                   " #{ENV.fetch('CPPFLAGS', nil)} -std=c++11  -gdwarf-2 -I$$ORIGIN/../ext/oboe_metal/src"
                 else
                   " #{ENV.fetch('CPPFLAGS', nil)} -std=c++11 -I$$ORIGIN/../ext/oboe_metal/src"
                 end

    $LIBS << " #{ENV.fetch('LIBS', nil)}"

    # -lrt option is used when linking programs with the GNU Compiler Collection (GCC) to
    # include the POSIX real-time extensions library, librt.
    $LDFLAGS << " #{ENV.fetch('LDFLAGS', nil)} '-Wl,-rpath=$$ORIGIN/../ext/oboe_metal/lib' -lrt"
    $CXXFLAGS += ' -std=c++11 '

    # OBOE_DEBUG need to be enabled before downloading and installing the gem
    if oboe_debug
      CONFIG['debugflags'] = '-ggdb3 '
      CONFIG['optflags'] = '-O0'
    end

    create_makefile('libsolarwinds_apm', 'src')
  else
    warn '== ERROR ========================================================='
    if have_library('oboe')
      warn "The c-library either needs to be updated or doesn't match the OS."
      warn 'No tracing will occur.'
    else
      warn 'Could not find a matching c-library. No tracing will occur.'
    end
    warn 'Contact technicalsupport@solarwinds.com if the problem persists.'
    warn '=================================================================='
    create_makefile('oboe_noop', 'noop')
  end
end
