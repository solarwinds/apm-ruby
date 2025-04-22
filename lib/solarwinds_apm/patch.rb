# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

# This file is for loading any customized patch for upstream

# e.g.
# require_relative './patch/dummy_patch'
# OpenTelemetry::Instrumentation::Registry.prepend(SolarWindsAPM::Patch::DummyPatch) if defined? OpenTelemetry::Instrumentation::Registry && OpenTelemetry::Instrumentation::Registry::VERSION <= '0.3.0'

require_relative 'sampling/sampling_patch'
