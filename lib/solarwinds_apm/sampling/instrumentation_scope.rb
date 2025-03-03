
module SolarWindsAPM
  module InstrumentationScope
    @lock = Mutex.new
    @version_cache = {} #

    ##
    # add the gem library version to event
    # p.s. gem library version is not same as the opentelemetry-instrumentation-* gem version
    def self.gather_instrumented_framework(span_data)
      scope_name = span_data.instrumentation_scope.name
      scope_name = scope_name.downcase if scope_name
      return unless scope_name&.include? 'opentelemetry::instrumentation'

      framework = scope_name.split('::')[2..]&.join('::')
      return if framework.nil? || framework.empty?

      framework         = normalize_framework_name(framework)
      framework_version = check_framework_version(framework)
      SolarWindsAPM.logger.debug do
        "[#{self.class}/#{__method__}] #{span_data.instrumentation_scope.name} with #{framework} and version #{framework_version}"
      end
      framework_version.nil? ? nil : { "Ruby.#{framework}.Version" => framework_version }
    end

    ##
    # helper function that extract gem library version for func add_instrumented_framework
    def self.check_framework_version(framework)
      framework_version = nil
      if @version_cache.key?(framework)

        framework_version = @version_cache[framework]
      else

        begin
          require framework
          framework_version = Gem.loaded_specs[version_framework_name(framework)].version.to_s
        rescue LoadError => e
          SolarWindsAPM.logger.debug do
            "[#{self.class}/#{__method__}] couldn't load #{framework} with error #{e.message}; skip"
          end
        rescue StandardError => e
          SolarWindsAPM.logger.debug do
            "[#{self.class}/#{__method__}] couldn't find #{framework} with error #{e.message}; skip"
          end
        ensure
          @lock.synchronize do
            @version_cache[framework] = framework_version
          end
        end
      end
      SolarWindsAPM.logger.debug do
        "[#{self.class}/#{__method__}] current framework version cached: #{@version_cache.inspect}"
      end
      framework_version
    end

    ##
    # helper function that convert opentelemetry instrumentation name to gem library understandable
    def self.normalize_framework_name(framework)
      { 'net::http' => 'net/http' }.fetch(framework, framework)
    end

    ##
    # helper function that convert opentelemetry instrumentation name to gem library understandable
    def self.version_framework_name(framework)
      { 'net/http' => 'net-http' }.fetch(framework, framework)
    end
  end
end
