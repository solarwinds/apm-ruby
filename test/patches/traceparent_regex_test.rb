# frozen_string_literal: true

# Copyright (c) 2023 SolarWinds, LLC.
# All rights reserved.

require 'minitest_helper'
require 'minitest/mock'
require './lib/solarwinds_apm/patches/tag_sql_constants'

describe 'traceparent_regex_test' do
  let(:traceparent_regex) { SolarWindsAPM::Patches::TagSqlConstants::TRACEPARENT_REGEX }

  it 'standard_sql_comments' do
    sql = "SELECT `a`.* FROM `a` WHERE `a`.`b` = 'abc' LIMIT 1 /*traceparent='00-f0ebd771266f8c359af8b10c1c57e623-aecd3d0c5c4f9a94-01'*/"
    matches = sql.match(traceparent_regex)
    _(matches.match(0)).must_equal "/*traceparent='00-f0ebd771266f8c359af8b10c1c57e623-aecd3d0c5c4f9a94-01'*/"
  end

  it 'sql_with_space' do
    sql = "SELECT `a`.* FROM `a` WHERE `a`.`b` = 'abc' LIMIT 1 /* traceparent='00-f0ebd771266f8c359af8b10c1c57e623-aecd3d0c5c4f9a94-01'   */"
    matches = sql.match(traceparent_regex)
    _(matches.match(0)).must_equal "/* traceparent='00-f0ebd771266f8c359af8b10c1c57e623-aecd3d0c5c4f9a94-01'   */"
  end

  it 'sql_without_single_quote' do
    sql = "SELECT `a`.* FROM `a` WHERE `a`.`b` = 'abc' LIMIT 1 /*traceparent=00-f0ebd771266f8c359af8b10c1c57e623-aecd3d0c5c4f9a94-01*/"
    matches = sql.match(traceparent_regex)
    _(matches.match(0)).must_equal '/*traceparent=00-f0ebd771266f8c359af8b10c1c57e623-aecd3d0c5c4f9a94-01*/'
  end

  it 'sql_without_single_quote_with_space' do
    sql = "SELECT `a`.* FROM `a` WHERE `a`.`b` = 'abc' LIMIT 1 /*   traceparent=00-f0ebd771266f8c359af8b10c1c57e623-aecd3d0c5c4f9a94-01   */"
    matches = sql.match(traceparent_regex)
    _(matches.match(0)).must_equal '/*   traceparent=00-f0ebd771266f8c359af8b10c1c57e623-aecd3d0c5c4f9a94-01   */'
  end

  it 'sql_with_wrong_format' do
    sql = "SELECT `a`.* FROM `a` WHERE `a`.`b` = 'abc' LIMIT 1 /*trace='00-f0ebd771266f8c359af8b10c1c57e623-aecd3d0c5c4f9a94-01'*/"
    matches = sql.match(traceparent_regex)
    assert_nil(matches)
  end

  it 'sql_with_wrong_format_on_context' do
    sql = "SELECT `a`.* FROM `a` WHERE `a`.`b` = 'abc' LIMIT 1 /*traceparent='00-aecd3d0c5c4f9a94-f0ebd771266f8c359af8b10c1c57e623-01'*/"
    matches = sql.match(traceparent_regex)
    assert_nil(matches)
  end
end
