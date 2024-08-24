# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

# rubocop:disable Lint/ConstantDefinitionInBlock
require 'minitest_helper'
require './lib/solarwinds_apm/patches/tag_sql_constants'

describe 'mysql2_client_patch' do
  before do
    module Mysql2
      class Client
        def config
          { db_statement: :obfuscate }
        end

        def mock_query(sql); end
      end
    end

    module OpenTelemetry
      module Instrumentation
        module Mysql2
          module Patches
            module Client
              # mocked client based on otel mysql2 instrumentation
              def mock_query(sql)
                _otel_span_attributes(sql)
              end

              def _otel_span_attributes(sql)
                attributes = {}
                case config[:db_statement]
                when :include
                  attributes[OpenTelemetry::SemanticConventions::Trace::DB_STATEMENT] = sql
                when :obfuscate
                  attributes[OpenTelemetry::SemanticConventions::Trace::DB_STATEMENT] = "SELECT `customers`.* FROM `customers` WHERE `customers`.`contactLastName` = '?' LIMIT '?'"
                end
                attributes
              end
            end
          end
        end
      end
      Mysql2::Client.prepend(OpenTelemetry::Instrumentation::Mysql2::Patches::Client)
    end
  end

  it 'mysql2_should_patch_when_exist_mysql2_and_instrumentation' do
    load File.expand_path('../../lib/solarwinds_apm/patches/mysql2_client_patch.rb', __dir__)
    _(Mysql2::Client.ancestors[0]).must_equal SolarWindsAPM::Patches::SWOMysql2ClientPatch
  end

  it 'should_keep_traceparent_when_obfuscate' do
    load File.expand_path('../../lib/solarwinds_apm/patches/mysql2_client_patch.rb', __dir__)
    client = Mysql2::Client.new
    attributes = client.mock_query("SELECT `customers`.* FROM `customers` WHERE `customers`.`contactLastName` = 'Schmitt' LIMIT 1 /*traceparent='00-f0ebd771266f8c359af8b10c1c57e623-aecd3d0c5c4f9a94-01'*/")
    _(attributes[OpenTelemetry::SemanticConventions::Trace::DB_STATEMENT]).must_equal "SELECT `customers`.* FROM `customers` WHERE `customers`.`contactLastName` = '?' LIMIT '?'/*traceparent='00-f0ebd771266f8c359af8b10c1c57e623-aecd3d0c5c4f9a94-01'*/"
  end

  it 'mysql2_should_not_change_anything_when_non_obfuscate' do
    module Mysql2
      class Client
        def config
          { db_statement: :include }
        end
      end
    end

    load File.expand_path('../../lib/solarwinds_apm/patches/mysql2_client_patch.rb', __dir__)
    client = Mysql2::Client.new
    attributes = client.mock_query("SELECT `customers`.* FROM `customers` WHERE `customers`.`contactLastName` = 'Schmitt' LIMIT 1 /*traceparent='00-f0ebd771266f8c359af8b10c1c57e623-aecd3d0c5c4f9a94-01'*/")
    _(attributes[OpenTelemetry::SemanticConventions::Trace::DB_STATEMENT]).must_equal "SELECT `customers`.* FROM `customers` WHERE `customers`.`contactLastName` = 'Schmitt' LIMIT 1 /*traceparent='00-f0ebd771266f8c359af8b10c1c57e623-aecd3d0c5c4f9a94-01'*/"
  end

  it 'mysql2_should_no_db_statement_include' do
    module Mysql2
      class Client
        def config
          { db_statement: :omit }
        end
      end
    end

    load File.expand_path('../../lib/solarwinds_apm/patches/mysql2_client_patch.rb', __dir__)
    client = Mysql2::Client.new
    attributes = client.mock_query("SELECT `customers`.* FROM `customers` WHERE `customers`.`contactLastName` = 'Schmitt' LIMIT 1 /*traceparent='00-f0ebd771266f8c359af8b10c1c57e623-aecd3d0c5c4f9a94-01'*/")
    assert_nil(attributes[OpenTelemetry::SemanticConventions::Trace::DB_STATEMENT])
  end
end

# rubocop:enable Lint/ConstantDefinitionInBlock