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
    class Validate
      attr_accessor :path

      def initialize(path)
        @path = path
      end

      def validate
        [:hostname, :version, :file_extension].each do |test|
          unless send(test)
            Rails.logger.error("Backup validation failed for #{test}.")
            return false
          end
        end

        true
      end

      protected

      def hostname
        hostname_file = File.join(path, "crowbar", "etc", "HOSTNAME")
        return false unless File.exist?(hostname_file)

        system_hostname = `hostname -f`.strip
        backup_hostname = File.open(hostname_file, &:readline).strip

        return false unless system_hostname == backup_hostname

        true
      end

      def version
        version_file = @path.join("crowbar", "version")

        unless version_file.file?
          return {
            status: :failed_dependency,
            msg: I18n.t(".version_file_missing", scope: "backup.validation")
          }
        end

        version = version_file.read.to_f
        if version < 1.9
          return {
            status: :failed_dependency,
            msg: I18n.t(".version_to_low", scope: "backup.validation")
          }
        elsif version > ENV["CROWBAR_VERSION"].to_f
          return {
            status: :failed_dependency,
            msg: I18n.t(".version_to_hight", scope: "backup.validation")
          }
        end

        true
      end

      def file_extension
        Dir.glob(File.join(path, "knife", "**", "*")).each do |file|
          next if Pathname.new(file).directory?
          unless File.extname(file) == ".json"
            return {
              status: :failed_dependency,
              msg: I18n.t(".non_json_file", scope: "backup.validation")
            }
          end
        end

        true
      end
    end
  end
end
