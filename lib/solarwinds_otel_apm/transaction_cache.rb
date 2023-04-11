module SolarWindsOTelAPM
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
      SolarWindsOTelAPM.logger.debug "############## current TransactionCache #{@cache.inspect}"
      @cache[key] = value
    end

  end
end

SolarWindsOTelAPM::TransactionCache.initialize