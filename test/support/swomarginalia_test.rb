require "minitest/autorun"
require "mocha/minitest"
require 'rails'
require 'logger'
require 'active_record'
require 'action_controller'
require 'active_job'
require 'sidekiq'
require 'sidekiq/testing'
require 'sqlite3'
require 'action_dispatch/middleware/request_id'

require 'minitest_helper'

require_relative './../../lib/solarwinds_otel_apm/support/swomarginalia/load_swomarginalia'

puts "Current rails version: #{Rails.version}"

# Shim for compatibility with older versions of MiniTest
MiniTest::Test = MiniTest::Unit::TestCase unless defined?(MiniTest::Test)

ActiveRecord::Base.establish_connection({
  adapter: 'sqlite3',
  database: 'database.db'
})

ActiveRecord::Base.connection.execute('CREATE TABLE IF NOT EXISTS posts( first_name TEXT NOT NULL, id TEXT NOT NULL)')
ActiveRecord::Base.connection.execute('INSERT OR IGNORE INTO posts(first_name, id) VALUES("fake_name", 456)')

class Post < ActiveRecord::Base
end

class PostsController < ActionController::Base
  def driver_only
    ActiveRecord::Base.connection.execute "select id from posts"
    render body: nil
  end
end

class PostsJob < ActiveJob::Base
  def perform
    Post.first
  end
end

class PostsSidekiqJob
  include Sidekiq::Worker
  def perform
    Post.first
  end
end

# has to override the traceparent for testing purpose
module SolarWindsOTelAPM
  module SWOMarginalia
    module Comment
      def self.traceparent
        format(
          '00-%<trace_id>s-%<span_id>s-%<trace_flags>.2d',
          trace_id: '85e9b1a685e9b1a685e9b1a685e9b1a6',
          span_id: '85e9b1a685e9b1a6',
          trace_flags: '01')
      end
    end
  end
end

# Has to insert after ActiveRecord defined
SolarWindsOTelAPM::SWOMarginalia::LoadSWOMarginalia.insert

describe 'SWOMarginaliaTestForRails6' do
  before do
    SolarWindsOTelAPM::SWOMarginalia.application_name = 'rails'
    @queries = []
    ActiveSupport::Notifications.subscribe "sql.active_record" do |*args|
      @queries << args.last[:sql]
    end
    @env = Rack::MockRequest.env_for('/')
    ActiveJob::Base.queue_adapter = :inline
  end

  after do 
    SolarWindsOTelAPM::SWOMarginalia.application_name = nil
    SolarWindsOTelAPM::SWOMarginalia::Comment.lines_to_ignore = nil
    SolarWindsOTelAPM::SWOMarginalia::Comment.components = [:traceparent]
    ActiveSupport::Notifications.unsubscribe "sql.active_record"
  end

  it 'test_query_commenting_on_sqlite3_driver_with_application_function' do
    SolarWindsOTelAPM::SWOMarginalia::Comment.components = [:application, :traceparent]
    Post.where(first_name: 'fake_name')
    _(@queries.first).must_equal "PRAGMA table_info(\"posts\") /*application='rails',traceparent='00-85e9b1a685e9b1a685e9b1a685e9b1a6-85e9b1a685e9b1a6-01'*/"
  end

  # Only ActiveRecord::Base.connection.raw_connection.prepare can do the prepare statement (the native connection)
  it 'test_query_commenting_on_sqlite3_driver_with_random_chars' do
    ActiveRecord::Base.connection.execute "select id from posts /* random_char */"
    _(@queries.first).must_equal "select id from posts /* random_char */ /*traceparent='00-85e9b1a685e9b1a685e9b1a685e9b1a6-85e9b1a685e9b1a6-01'*/"
  end

  it 'test_query_commenting_on_sqlite3_driver_with_action' do
    PostsController.action(:driver_only).call(@env)
    _(@queries.first).must_equal "select id from posts /*traceparent='00-85e9b1a685e9b1a685e9b1a685e9b1a6-85e9b1a685e9b1a6-01'*/"
  end

  it 'test_query_commenting_on_sqlite3_driver_with_nothing' do
    SolarWindsOTelAPM::SWOMarginalia::Comment.components = []
    ActiveRecord::Base.connection.execute "select id from posts"
    _(@queries.last).must_equal "select id from posts"
  end

  it 'test_proc_function_traceparent_for_rails_7' do
    traceparent = SolarWindsOTelAPM::SWOMarginalia::Comment.traceparent
    traceparent = traceparent.split('-')
    _(traceparent[0]).must_equal '00'
    _(traceparent[1].size).must_equal 32
    _(traceparent[2].size).must_equal 16
    _(traceparent[3].size).must_equal 2
  end

end