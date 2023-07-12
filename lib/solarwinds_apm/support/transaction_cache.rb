module SolarWindsAPM
  # Simple TransactionCache
  # TODO: improve cache to have lru mechanism that avoid too many values
  module TransactionCache
    def self.initialize
      @cache = {}
    end

    def self.get(key)
      @cache[key]
    end

    def self.del(key)
      @cache.delete(key)
    end

    def self.set(key, value)
      @cache[key] = value
      SolarWindsAPM.logger.debug "[#{self.class}/#{__method__}] current TransactionCache #{@cache.inspect}"
    end
  end
end

SolarWindsAPM::TransactionCache.initialize