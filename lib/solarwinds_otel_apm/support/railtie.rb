require 'rails/railtie'
require_relative './swomarginalia/swomarginalia'

module SolarWindsOTelAPM
  module SWOMarginalia
    class Railtie < Rails::Railtie
      initializer 'swomarginalia.insert' do
        ActiveSupport.on_load :active_record do
          ::SolarWindsOTelAPM::SWOMarginalia::Railtie.insert_into_active_record
        end

        ActiveSupport.on_load :action_controller do
          ::SolarWindsOTelAPM::SWOMarginalia::Railtie.insert_into_action_controller
        end

        ActiveSupport.on_load :active_job do
          ::SolarWindsOTelAPM::SWOMarginalia::Railtie.insert_into_active_job
        end
      end

      def self.insert
        insert_into_active_record
        insert_into_action_controller
        insert_into_active_job
      end

      def self.insert_into_active_job
        return unless defined? ActiveJob::Base
        
        ActiveJob::Base.class_eval do
          around_perform do |job, block|
            begin
              SWOMarginalia::Comment.update_job! job
              block.call
            ensure
              SWOMarginalia::Comment.clear_job!
            end
          end
        end
      end      

      def self.insert_into_action_controller
        return unless defined? ActionController::Base

        ActionController::Base.include SWOMarginalia::ActionControllerInstrumentation
        
        return unless defined? ActionController::API

        ActionController::API.include SWOMarginalia::ActionControllerInstrumentation
      end

      def self.insert_into_active_record
        if defined? ActiveRecord::ConnectionAdapters::Mysql2Adapter
          ActiveRecord::ConnectionAdapters::Mysql2Adapter.module_eval do
            include SWOMarginalia::ActiveRecordInstrumentation
          end
        end

        if defined? ActiveRecord::ConnectionAdapters::MysqlAdapter
          ActiveRecord::ConnectionAdapters::MysqlAdapter.module_eval do
            include SWOMarginalia::ActiveRecordInstrumentation
          end
        end

        if defined? ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
          ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.module_eval do
            include SWOMarginalia::ActiveRecordInstrumentation
          end
        end

        return unless defined? ActiveRecord::ConnectionAdapters::SQLite3Adapter

        ActiveRecord::ConnectionAdapters::SQLite3Adapter.module_eval do
          include SWOMarginalia::ActiveRecordInstrumentation
        end
        
      end
    end
  end
end