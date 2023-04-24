# == Schema Information
#
# Table name: google_firebase_integrations
#
#  id                :uuid             not null, primary key
#  json_key          :string
#  original_json_key :string
#  project_number    :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  app_id            :string
#
class GoogleFirebaseIntegration < ApplicationRecord
  has_paper_trail
  encrypts :json_key, deterministic: true

  include Providable
  include Displayable
  include Loggable

  delegate :cache, to: Rails
  delegate :app, to: :integration

  validate :correct_key, on: :create

  attr_accessor :json_key_file

  def access_key
    StringIO.new(json_key)
  end

  def installation
    Installations::Google::Firebase::Api.new(project_number, app_id, access_key)
  end

  def creatable?
    true
  end

  def connectable?
    false
  end

  def store?
    true
  end

  def controllable_rollout?
    false
  end

  def to_s
    "firebase"
  end

  GROUPS_TRANSFORMATIONS = {
    id: :name,
    name: :display_name,
    member_count: :tester_count
  }

  EMPTY_CHANNEL = {id: :no_testers, name: "No testers (upload only)"}

  def channels
    installation.list_groups(GROUPS_TRANSFORMATIONS)
  end

  def build_channels_cache_key
    "app/#{app.id}/google_firebase_integration/#{id}/build_channels"
  end

  def build_channels(with_production:)
    sliced = cache.fetch(build_channels_cache_key, expires_in: 30.minutes) do
      channels.map { |channel| channel.slice(:id, :name) }
    end

    sliced.push(EMPTY_CHANNEL)
  end

  def upload(file)
    GitHub::Result.new do
      installation.upload(file)
    end
  end

  def get_upload_status(op_name)
    GitHub::Result.new do
      upload_status = installation.get_upload_status(op_name)
      if upload_status[:done] && upload_status[:error]
        raise Installations::Error.new(upload_status[:error][:message], reason: :upload_failed)
      end
      upload_status
    end
  end

  def release(release_name, group)
    GitHub::Result.new do
      group_name = group.split("/").last
      installation.send_to_group(release_name, group_name)
    end
  end

  private

  def releases_present?
    installation.list_releases
  end

  def correct_key
    releases_present?
  rescue RuntimeError
    errors.add(:json_key, :key_format)
  rescue Installations::Google::Firebase::Error => ex
    errors.add(:json_key, ex.reason)
  end
end
