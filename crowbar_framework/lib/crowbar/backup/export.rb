#
# Copyright 2011-2013, Dell
# Copyright 2013-2015, SUSE LINUX GmbH
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

require "chef"
require "yaml_db"

module Crowbar
  class Backup
    class Export < Base
      attr_accessor :path

      def initialize(path)
        self.path = path
      end

      def export
        clients
        nodes
        roles
        databags
        db
        crowbar
      end

      def clients
        chef(
          "client",
          "::Chef::ApiClient"
        )
      end

      def nodes
        chef(
          "node",
          "::Chef::Node"
        )
      end

      def roles
        chef(
          "role",
          "::Chef::Role"
        )
      end

      def databags
        logger.debug "Backing up databags"

        data_dir = workdir.join("knife", "databags")
        data_dir.mkpath unless data_dir.directory?

        Chef::DataBag.list.each do |name, url|
          bag_dir = data_dir.join(name)
          bag_dir.mkpath unless bag_dir.directory?

          Chef::DataBag.load(name).each do |item, item_url|
            logger.debug "Backing up databag #{name}/#{item}"

            record = Chef::DataBagItem.load(
              name,
              item
            )

            bag_dir.join("#{item}.json").open("w") do |file|
              file.write JSON.pretty_generate(
                record
              )
            end
          end
        end
      end

      def db
        logger.debug "Backing up database"

        data_dir = workdir.join("crowbar")
        data_dir.mkpath unless data_dir.directory?

        SerializationHelper::Base.new(
          YamlDb::Helper
        ).dump(
          data_dir.join(
            "database.#{YamlDb::Helper.extension}"
          )
        )
      end

      def crowbar
        logger.debug "Backing up Crowbar Files"

        data_dir = workdir.join("crowbar")
        ["tftp", "etc", "crowbar", "root"].each do |folder|
          absolute_path = data_dir.join(folder)
          absolute_path.mkpath unless absolute_path.directory?
        end

        self.class.export_files.each do |filemap|
          destination, source = filemap
          if destination =~ /resolv.conf/
            data_dir.join(source).open("w") do |file|
              forwarders.each do |forwarder|
                file.write("nameserver #{forwarder}")
              end
            end
          else
            FileUtils.cp_r(destination, data_dir.join(source))
          end
        end

        data_dir.join("version").open("w") do |file|
          file.write(ENV["CROWBAR_VERSION"])
        end
      end

      protected

      def forwarders
        f = File.open("/etc/bind/named.conf")
        arr = []
        write = false
        f.each_line do |line|
          if line =~ /forwarders {/
            write = true
            next
          end
          write = false if write && line =~ /};/
          arr.push(line) if write
        end
        arr.map(&:chomp!).map(&:strip!)
        arr.each { |s| s.slice!(";") }
      end

      def workdir
        @workdir ||= Pathname.new(
          path
        )
      end

      def chef(component, klass)
        logger.debug "Backing up #{component.pluralize}"

        data_dir = workdir.join("knife", component.pluralize)
        data_dir.mkpath unless data_dir.directory?

        klass.constantize.list.each do |name, url|
          logger.debug "Backing up #{component} #{name}"

          record = klass.constantize.load(
            name
          ).to_hash.merge(
            json_class: klass.constantize.to_s
          )

          unless record
            logger.error "Faild to load #{component} #{name}"
            next
          end

          data_dir.join("#{name}.json").open("w") do |file|
            file.write JSON.pretty_generate(
              record
            )
          end
        end
      end
    end
  end
end
