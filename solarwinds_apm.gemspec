# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)
require 'solarwinds_apm/version'

Gem::Specification.new do |s|
  s.name = 'solarwinds_apm'
  s.version = SolarWindsAPM::Version::STRING

  s.license  = 'Apache-2.0'

  s.authors  = ['Maia Engeli', 'Peter Giacomo Lombardo', 'Spiros Eliopoulos', 'Xuan Cao']
  s.email    = 'technicalsupport@solarwinds.com'
  s.homepage = 'https://documentation.solarwinds.com/en/success_center/observability/content/intro/landing-page.html'
  s.summary  = 'SolarWindsAPM performance instrumentation gem for Ruby'
  s.description = 'Automatic tracing and metrics for Ruby applications. Get started at cloud.solarwinds.com'

  s.metadata = { 'changelog_uri' => 'https://github.com/solarwinds/apm-ruby/releases',
                 'documentation_uri' => 'https://documentation.solarwinds.com/en/success_center/observability/default.htm#cshid=config-ruby-agent',
                 'homepage_uri' => 'https://documentation.solarwinds.com/en/success_center/observability/content/intro/landing-page.html',
                 'source_code_uri' => 'https://github.com/solarwinds/apm-ruby',
                 'github_repo' => 'https://github.com/solarwinds/apm-ruby.git',
                 'rubygems_mfa_required' => 'true' }

  s.extra_rdoc_files = ['LICENSE']
  # s.files = `git ls-files`.split("\n").reject { |f| f.match(%r{^(test|gemfiles)/}) }
  s.files = Dir['lib/**/*']
  s.files += ['ext/oboe_metal/src/oboe.h',
              'ext/oboe_metal/src/oboe_api.cpp',
              'ext/oboe_metal/src/oboe_api.h',
              'ext/oboe_metal/src/oboe_debug.h',
              'ext/oboe_metal/src/oboe_swig_wrap.cc',
              'ext/oboe_metal/src/bson/bson.h',
              'ext/oboe_metal/src/bson/platform_hacks.h',
              'ext/oboe_metal/src/init_solarwinds_apm.cc',
              'ext/oboe_metal/src/VERSION',
              'ext/oboe_metal/lib/liboboe-1.0-alpine-x86_64.so.sha256',
              'ext/oboe_metal/lib/liboboe-1.0-x86_64.so.sha256',
              'ext/oboe_metal/lib/liboboe-1.0-aarch64.so.sha256',
              'ext/oboe_metal/lib/liboboe-1.0-alpine-aarch64.so.sha256',
              'ext/oboe_metal/lib/liboboe-1.0-lambda-x86_64.so.sha256',
              'ext/oboe_metal/lib/liboboe-1.0-lambda-aarch64.so.sha256']

  s.files -= ['Rakefile']

  s.extensions = ['ext/oboe_metal/extconf.rb']

  # OTEL dependencies
  s.add_dependency('opentelemetry-instrumentation-all', '>= 0.31.0')
  s.add_dependency('opentelemetry-sdk', '>= 1.2.0')

  # this still gives a warning, would have to be pinned to a minor version
  # but that is not necessary and may restrict other gems
  s.add_dependency('json', '~> 2.0')

  s.required_ruby_version = '>= 2.7.0'
  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
end
