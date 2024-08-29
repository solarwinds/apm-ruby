# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

# rubocop:disable Lint/ConstantDefinitionInBlock
require 'minitest_helper'
require './lib/solarwinds_apm/patches/tag_sql_constants'

describe 'tag_sql_patch_test' do
  before do
    class Trilogy
      def config
        { db_statement: :obfuscate }
      end

      def mock_query(sql); end
    end

    module OpenTelemetry
      module Instrumentation
        module Trilogy
          module Patches
            module Client
              # mocked client based on otel trilogy instrumentation
              def mock_query(sql)
                client_attributes(sql)
              end

              def client_attributes(sql)
                attributes = {}
                if sql
                  case config[:db_statement]
                  when :obfuscate
                    attributes[OpenTelemetry::SemanticConventions::Trace::DB_STATEMENT] = "SELECT `customers`.* FROM `customers` WHERE `customers`.`contactLastName` = '?' LIMIT '?'"
                  when :include
                    attributes[OpenTelemetry::SemanticConventions::Trace::DB_STATEMENT] = sql
                  end
                end

                attributes
              end
            end
          end
        end
      end
      Trilogy.prepend(OpenTelemetry::Instrumentation::Trilogy::Patches::Client)
    end
  end

  it 'trilogy_should_patch_when_exist_trilogy_and_instrumentation' do
    load File.expand_path('../../lib/solarwinds_apm/patches/trilogy_client_patch.rb', __dir__)
    _(Trilogy.ancestors[0]).must_equal SolarWindsAPM::Patches::SWOTrilogyClientPatch
  end

  it 'should_keep_traceparent_when_obfuscate' do
    load File.expand_path('../../lib/solarwinds_apm/patches/trilogy_client_patch.rb', __dir__)
    client = Trilogy.new
    attributes = client.mock_query("SELECT `customers`.* FROM `customers` WHERE `customers`.`contactLastName` = 'Schmitt' LIMIT 1 /*traceparent='00-f0ebd771266f8c359af8b10c1c57e623-aecd3d0c5c4f9a94-01'*/")
    _(attributes[OpenTelemetry::SemanticConventions::Trace::DB_STATEMENT]).must_equal "SELECT `customers`.* FROM `customers` WHERE `customers`.`contactLastName` = '?' LIMIT '?'/*traceparent='00-f0ebd771266f8c359af8b10c1c57e623-aecd3d0c5c4f9a94-01'*/"
  end

  it 'trilogy_should_not_change_anything_when_non_obfuscate' do
    class Trilogy
      def config
        { db_statement: :include }
      end
    end

    load File.expand_path('../../lib/solarwinds_apm/patches/trilogy_client_patch.rb', __dir__)
    client = Trilogy.new
    attributes = client.mock_query("SELECT `customers`.* FROM `customers` WHERE `customers`.`contactLastName` = 'Schmitt' LIMIT 1 /*traceparent='00-f0ebd771266f8c359af8b10c1c57e623-aecd3d0c5c4f9a94-01'*/")
    _(attributes[OpenTelemetry::SemanticConventions::Trace::DB_STATEMENT]).must_equal "SELECT `customers`.* FROM `customers` WHERE `customers`.`contactLastName` = 'Schmitt' LIMIT 1 /*traceparent='00-f0ebd771266f8c359af8b10c1c57e623-aecd3d0c5c4f9a94-01'*/"
  end

  it 'trilogy_should_no_db_statement_include' do
    class Trilogy
      def config
        { db_statement: :omit }
      end
    end

    load File.expand_path('../../lib/solarwinds_apm/patches/trilogy_client_patch.rb', __dir__)
    client = Trilogy.new
    attributes = client.mock_query("SELECT `customers`.* FROM `customers` WHERE `customers`.`contactLastName` = 'Schmitt' LIMIT 1 /*traceparent='00-f0ebd771266f8c359af8b10c1c57e623-aecd3d0c5c4f9a94-01'*/")
    assert_nil(attributes[OpenTelemetry::SemanticConventions::Trace::DB_STATEMENT])
  end
end

# rubocop:enable Lint/ConstantDefinitionInBlock
