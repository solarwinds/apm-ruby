# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

# rubocop:disable Lint/ConstantDefinitionInBlock
require 'minitest_helper'
require './lib/solarwinds_apm/patches/tag_sql_constants'

describe 'pg_connection_patch' do
  before do
    module PG
      class Connection
        def config
          { db_statement: :obfuscate }
        end

        def mock_query(sql); end
      end
    end

    module OpenTelemetry
      module Instrumentation
        module PG
          module Patches
            module Connection
              # mocked client based on otel pg instrumentation
              def mock_query(sql)
                obfuscate_sql(sql)
              end

              def obfuscate_sql(sql)
                return sql unless config[:db_statement] == :obfuscate

                "SELECT `customers`.* FROM `customers` WHERE `customers`.`contactLastName` = '?' LIMIT '?'"
              end
            end
          end
        end
      end
      PG::Connection.prepend(OpenTelemetry::Instrumentation::PG::Patches::Connection)
    end
  end

  it 'pg_should_patch_when_exist_pg_and_instrumentation' do
    load File.expand_path('../../lib/solarwinds_apm/patches/pg_connection_patch.rb', __dir__)
    _(PG::Connection.ancestors[0]).must_equal SolarWindsAPM::Patches::SWOPgConnectionPatch
  end

  it 'should_keep_traceparent_when_obfuscate' do
    load File.expand_path('../../lib/solarwinds_apm/patches/pg_connection_patch.rb', __dir__)
    client = PG::Connection.new
    pg_sql = client.mock_query("SELECT `customers`.* FROM `customers` WHERE `customers`.`contactLastName` = 'Schmitt' LIMIT 1 /*traceparent='00-f0ebd771266f8c359af8b10c1c57e623-aecd3d0c5c4f9a94-01'*/")
    _(pg_sql).must_equal "SELECT `customers`.* FROM `customers` WHERE `customers`.`contactLastName` = '?' LIMIT '?'/*traceparent='00-f0ebd771266f8c359af8b10c1c57e623-aecd3d0c5c4f9a94-01'*/"
  end

  it 'pg_should_not_change_anything_when_non_obfuscate' do
    module PG
      class Connection
        def config
          { db_statement: :include }
        end
      end
    end

    load File.expand_path('../../lib/solarwinds_apm/patches/pg_connection_patch.rb', __dir__)
    client = PG::Connection.new
    pg_sql = client.mock_query("SELECT `customers`.* FROM `customers` WHERE `customers`.`contactLastName` = 'Schmitt' LIMIT 1 /*traceparent='00-f0ebd771266f8c359af8b10c1c57e623-aecd3d0c5c4f9a94-01'*/")
    _(pg_sql).must_equal "SELECT `customers`.* FROM `customers` WHERE `customers`.`contactLastName` = 'Schmitt' LIMIT 1 /*traceparent='00-f0ebd771266f8c359af8b10c1c57e623-aecd3d0c5c4f9a94-01'*/"
  end

  # pg obfuscate_sql function doesn't test for omit, span_attrs will omit the sql
end

# rubocop:enable Lint/ConstantDefinitionInBlock
