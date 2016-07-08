
#
# Copyright 2016, SUSE Linux GmbH
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

class Api::V2::CrowbarController < ApplicationController
  api :GET, "/api/v2/crowbar", "Show the crowbar object"
  def show
    render json: {}
  end

  api :PATCH, "/api/v2/crowbar", "Update Crowbar object"
  def update
    render json: {}
  end

  api :POST, "/api/v2/crowbar/upgrade", "Upgrade Crowbar"
  def upgrade
    render json: {}
  end

  api :GET, "/api/v2/crowbar/repositories/check", "Sanity check crowbar repositories"
  def repocheck
    render json: {}
  end
end
