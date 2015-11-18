#
# Copyright 2015, SUSE LINUX Products GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module Crowbar
  class Backup
    class Restore
      attr_accessor :backup, :version

      def initialize(backup)
        @backup = backup
        @data = @backup.data
        @version = @backup.version
      end

      def restore
        [:crowbar, :knife, :database].each do |component|
          ret = send(component)
          return ret unless ret == true
        end
      end

      protected

      def knife
        [:nodes, :roles, :clients].each do |type|
          @data.join("knife", type.to_s).children.each do |file|
            record = JSON.load(file.read)
            record.save
          end
        end
        @data.join("knife", "databags", "crowbar").children.each do |file|
          next unless file.basename.to_s.match(/\A\w+-\w+\.json\z/) && \
              !file.basename.to_s.match(/\Atemplate-.*/)
          json = JSON.load(file.read)
          bc_name = file.basename.to_s.split("-").first
          Proposal.create(barclamp: bc_name, name: "default", properties: json)
        end
      end

      def crowbar
        Crowbar::Backup::Base.restore_files.each do |source, destionation|
          FileUtils.cp_r(@data.join("crowbar", source), destionation)
        end
      end

      def database
        SerializationHelper::Base.new(YamlDb::Helper).load(
          @data.join("crowbar", "database.yml")
        )
        Crowbar::Migrate.migrate!
      end
    end
  end
end
