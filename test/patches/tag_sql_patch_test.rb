# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

# rubocop:disable Lint/ConstantDefinitionInBlock
require 'minitest_helper'

describe 'trilogy_client_patch' do
  it 'should_not_patch_if_tag_sql_is_false' do
    load File.expand_path('../../lib/solarwinds_apm/patches/tag_sql_constants.rb', __dir__)

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
