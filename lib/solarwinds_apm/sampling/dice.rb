# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

# Dice is used in oboe_sampler diceRollAlgo
module SolarWindsAPM
  class Dice
    attr_reader :rate, :scale

    def initialize(settings)
      @scale = settings[:scale]
      @rate = settings[:rate] || 0
    end

    def update(settings)
      @scale = settings[:scale] if settings[:scale]
      @rate = settings[:rate] if settings[:rate]
    end

    # return Boolean
    def roll
      (rand * @scale) < @rate
    end

    def rate=(rate)
      # Math.max(0, Math.min(this.#scale, n))
      @rate = rate.clamp(0, @scale)
    end
  end
end
