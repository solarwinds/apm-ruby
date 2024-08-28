# frozen_string_literal: true

# © 2023 SolarWinds Worldwide, LLC. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at:http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

require_relative 'swomarginalia'

module SolarWindsAPM
  module SWOMarginalia
    module LoadSWOMarginalia
      def self.insert
        insert_into_active_record
        insert_into_action_controller
        insert_into_active_job
      end

      def self.insert_into_active_job
        return unless defined? ::ActiveJob::Base

        ::ActiveJob::Base.class_eval do
          around_perform do |job, block|
            SWOMarginalia::Comment.update_job! job
            block.call
          ensure
            SWOMarginalia::Comment.clear_job!
          end
        end
      end

      def self.insert_into_action_controller
        return unless defined? ::ActionController::Base

        ::ActionController::Base.include SWOMarginalia::ActionControllerInstrumentation

        return unless defined? ::ActionController::API

        ::ActionController::API.include SWOMarginalia::ActionControllerInstrumentation
      end

      def self.insert_into_active_record
        ActiveRecord::ConnectionAdapters::Mysql2Adapter.prepend(SWOMarginalia::ActiveRecordInstrumentation)     if defined? ActiveRecord::ConnectionAdapters::Mysql2Adapter
        ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(SWOMarginalia::ActiveRecordInstrumentation) if defined? ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
        ActiveRecord::ConnectionAdapters::SQLite3Adapter.prepend(SWOMarginalia::ActiveRecordInstrumentation)    if defined? ActiveRecord::ConnectionAdapters::SQLite3Adapter
        ActiveRecord::ConnectionAdapters::TrilogyAdapter.prepend(SWOMarginalia::ActiveRecordInstrumentation)    if defined? ActiveRecord::ConnectionAdapters::TrilogyAdapter
      end
    end
  end
end
