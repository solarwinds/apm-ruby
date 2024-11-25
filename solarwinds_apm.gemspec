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
                 'rubygems_mfa_required' => 'true' }

  s.extra_rdoc_files = ['LICENSE']
  # s.files = `git ls-files`.split("\n").reject { |f| f.match(%r{^(test|gemfiles)/}) }
  s.files = Dir['lib/**/*']
  s.files += ['.yardopts', 'README.md', 'LICENSE']
  s.files += ['ext/oboe_metal/src/oboe.h',
              'ext/oboe_metal/src/oboe_api.cpp',
              'ext/oboe_metal/src/oboe_api.h',
              'ext/oboe_metal/src/oboe_debug.h',
              'ext/oboe_metal/src/oboe_swig_wrap.cc',
              'ext/oboe_metal/src/bson/bson.h',
              'ext/oboe_metal/src/bson/platform_hacks.h',
              'ext/oboe_metal/src/init_solarwinds_apm.cc',
              'ext/oboe_metal/src/VERSION']
  s.files += Dir['ext/oboe_metal/lib/*']

  s.files -= ['Rakefile']

  s.extensions = ['ext/oboe_metal/extconf.rb']

  s.add_dependency('opentelemetry-exporter-otlp-metrics', '>= 0.1.0')
  s.add_dependency('opentelemetry-instrumentation-all', '>= 0.31.0')
  s.add_dependency('opentelemetry-metrics-sdk', '>= 0.1.0')
  s.add_dependency('opentelemetry-sdk', '>= 1.2.0')

  s.required_ruby_version = '>= 2.7.0'
  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
end
