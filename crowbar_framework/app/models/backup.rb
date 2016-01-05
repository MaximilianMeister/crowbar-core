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

require "find"

class Backup < ActiveRecord::Base
  attr_accessor :file

  before_validation :save_or_create_archive, on: :create
  after_destroy :delete_archive

  validates :name,
    presence: true,
    uniqueness: true,
    format: {
      with: /\A[a-zA-Z0-9\-_]+\z/,
      message: "allows only letters and numbers"
    }
  validates :version,
    presence: true
  validates :size,
    presence: true

  def exist?
    self.class.image_dir.join("#{self.name}.tar.gz").exist?
  end

  def path
    self.class.image_dir.join("#{self.name}.tar.gz")
  end

  def filename
    "#{self.name}.tar.gz"
  end

  def extract
    backup_dir = Dir.mktmpdir
    Archive.extract(self.path.to_s, backup_dir)
    Pathname.new(backup_dir)
  end

  def data
    @data ||= extract
  end

  def data_valid?
    validate = Crowbar::Backup::Validate.new(data)
    validate.validate
  end

  def restore
    upgrade if upgrade?
    ret = data_valid?
    return ret unless ret[:status] == :ok
    Crowbar::Backup::Restore.new(self).restore
  end

  def upgrade?
    ENV["CROWBAR_VERSION"].to_f > self.version
  end

  def upgrade
    upgrade = Crowbar::Upgrade.new(self)
    if upgrade.supported?
      upgrade.upgrade
    else
      return {
        status: :not_acceptable,
        msg: I18n.t(
          "backup.index.upgrade_not_supported"
        )
      }
    end
  end

  class << self
    def image_dir
      if Rails.env.production?
        Pathname.new("/var/lib/crowbar/backup")
      else
        Rails.root.join("storage")
      end
    end
  end

  protected

  def save_or_create_archive
    if self.name.blank?
      save_archive
    else
      create_archive
    end
  end

  def create_archive
    dir = Dir.mktmpdir
    path = self.class.image_dir.join("#{self.name}.tar.gz")

    Crowbar::Backup::Export.new(dir).export
    Dir.chdir(dir) do
      ar = Archive::Compress.new(
        path.to_s,
        type: :tar,
        compression: :gzip
      )
      ar.compress(::Find.find(".").select { |f| f.gsub!(/^.\//, "") if ::File.file?(f) })
    end
    self.version = ENV["CROWBAR_VERSION"]
    self.size = path.size
  ensure
    FileUtils.rm_rf(dir)
  end

  def save_archive
    self.name = self.file.original_filename.split(".").first

    if self.class.image_dir.join("#{self.name}.tar.gz").exist?
      errors.add(:filename, I18n.t(".invalid_filename", scope: "backups.index"))
      return false
    end

    self.class.image_dir.join("#{self.name}.tar.gz").open("wb") do |f|
      f.write(self.file.read)
    end

    meta = YAML::load_file(self.data.join("crowbar", "meta.yml"))
    self.version = meta["version"]
    self.size = self.class.image_dir.join("#{self.name}.tar.gz").size
    self.created_at = DateTime.parse(meta["created_at"])
  end

  def delete_archive
    archive = self.class.image_dir.join("#{self.name}.tar.gz")
    archive.delete if archive.exist?
  end
end
