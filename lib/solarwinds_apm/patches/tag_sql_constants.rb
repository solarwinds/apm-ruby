# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

module SolarWindsAPM
  module Patches
  	module TagSqlConstants
  		TRACEPARENT_REGEX = /\/\*\s*traceparent=?'?[0-9a-f]{2}-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}'?\s*\*\//
  	end
  end
end