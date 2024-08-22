# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

if SolarWindsAPM::Config[:tag_sql]
  require_relative 'tag_sql_constants'
  require_relative 'mysql2_client_patch'
  require_relative 'pg_connection_patch'
  require_relative 'trilogy_client_patch'
end
