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
  s.files = Dir['lib/**/*']
  s.files += ['.yardopts', 'README.md', 'LICENSE']
  s.files -= ['Rakefile']

  s.add_dependency('opentelemetry-exporter-otlp', '>= 0.29.1')
  s.add_dependency('opentelemetry-exporter-otlp-logs', '>= 0.2.1')
  s.add_dependency('opentelemetry-exporter-otlp-metrics', '>= 0.3.0')
  s.add_dependency('opentelemetry-instrumentation-all', '>= 0.31.0')
  s.add_dependency('opentelemetry-logs-sdk', '>= 0.4.0')
  s.add_dependency('opentelemetry-metrics-sdk', '>= 0.2.0')
  s.add_dependency('opentelemetry-resource-detector-aws', '>= 0.1.0')
  s.add_dependency('opentelemetry-resource-detector-azure', '>= 0.2.0')
  s.add_dependency('opentelemetry-resource-detector-container', '>= 0.2.0')
  s.add_dependency('opentelemetry-sdk', '>= 1.2.0')

  s.required_ruby_version = '>= 3.1.0'
  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
end
