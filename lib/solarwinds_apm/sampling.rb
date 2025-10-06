# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require 'json'
require 'fileutils'
require 'tempfile'
require 'uri'

require_relative 'sampling/sampling_constants'
require_relative 'sampling/dice'
require_relative 'sampling/settings'
require_relative 'sampling/token_bucket'
require_relative 'sampling/trace_options'
require_relative 'sampling/metrics'

# HttpSampler/JsonSampler < Sampler < OboeSampler
require_relative 'sampling/oboe_sampler'
require_relative 'sampling/sampler'
require_relative 'sampling/http_sampler'
require_relative 'sampling/json_sampler'

# Patching
require_relative 'sampling/sampling_patch'
