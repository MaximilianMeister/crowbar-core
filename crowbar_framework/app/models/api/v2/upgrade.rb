#
# Copyright 2016, SUSE LINUX GmbH
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

class Api::V2::Upgrade < ActiveRecord::Base
  validates :from_version,
    presence: true,
    uniqueness: true,
    inclusion: {
      in: [3.0],
      message: "Version not supported"
    }
  validates :to_version,
    presence: true,
    uniqueness: true,
    inclusion: {
      in: [4.0],
      message: "Version not supported"
    }
  validate :validate_sanity,
    :validate_maintenance_updates,
    :validate_cluster_health, on: :create

  protected

  def validate_sanity
    Crowbar::Sanity.sane?
  end

  def validate_maintenance_updates
     system("zypper patch-check")
     if $?.exitstatus == 101
       errors.add(:maintenance_updates_missing, "Please install maintenace updates first")
     end
  end
end
