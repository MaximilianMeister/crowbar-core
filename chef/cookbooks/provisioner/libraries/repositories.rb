#
# Copyright 2013-2014, SUSE LINUX Products GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class Provisioner
  class Repositories
    class << self
      def inspect_repos(node)
        require "#{node.rails.root}/lib/crowbar/repository"

        unless node.roles.include? "provisioner-server"
          raise "Internal error: inspect_repos method should only be called on provisioner-server node."
        end

        platforms = Crowbar::Repository.all_platforms
        common_available, cloud_available, hae_available, storage_available = nil

        case node[:platform]
        when "suse"
          platforms.select { |pl| pl =~ /suse/ }.each do |platform|
            Crowbar::Repository.where(platform: platform).each do |repo|
              case repo.registry["product_name"]
              when "common"
                common_available = repo.available?
              when "cloud"
                cloud_available = repo.available?
              when "hae"
                hae_available = repo.available?
              when "storage"
                storage_available = repo.available?
              end
            end
          end

          # set an attribute about available repos so that cookbooks and crowbar
          # know that HA can be used
          # know that SUSE_Storage can be used
          # know that OpenStack can be used
          node_set = false
          node.set[:provisioner][:suse] ||= {}
          if node[:provisioner][:suse][:common_available] != common_available
            node.set[:provisioner][:suse][:common_available] = common_available
            node_set = true
          end
          if node[:provisioner][:suse][:cloud_available] != cloud_available
            node.set[:provisioner][:suse][:cloud_available] = cloud_available
            node_set = true
          end
          if node[:provisioner][:suse][:hae_available] != hae_available
            node.set[:provisioner][:suse][:hae_available] = hae_available
            node_set = true
          end
          if node[:provisioner][:suse][:storage_available] != storage_available
            node.set[:provisioner][:suse][:storage_available] = storage_available
            node_set = true
          end
          if node_set
            node.save
          end
        end
      end

      # This returns a hash containing the data about the repos that must be
      # used on nodes; optional repos (such as HA) will only be returned if
      # they can be used.
      def get_repos(provisioner_server_node, platform, version)
        Crowbar::API.repositories
      end
    end
  end
end
