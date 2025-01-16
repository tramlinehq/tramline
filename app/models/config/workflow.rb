# == Schema Information
#
# Table name: workflow_configs
#
#  id                         :bigint           not null, primary key
#  artifact_name_pattern      :string
#  build_suffix               :string
#  identifier                 :string
#  kind                       :string
#  name                       :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  release_platform_config_id :bigint           indexed
#
class Config::Workflow < ApplicationRecord
  self.table_name = "workflow_configs"

  belongs_to :release_platform_config, class_name: "Config::ReleasePlatform"

  enum :kind, {internal: "internal", release_candidate: "release_candidate"}
  validates :identifier, :name, presence: true
  validates :build_suffix, absence: true, if: :ios?

  delegate :ios?, to: :release_platform_config

  BUILD_SUFFIX_SEPARATOR = "-"

  def as_json(options = {})
    {
      id: identifier,
      name:,
      artifact_name_pattern:,
      kind:,
      build_suffix:
    }
  end

  def self.from_json(json)
    workflow = new(json.except("id")) # Exclude 'id' to ensure we don't overwrite an existing object
    workflow.identifier = json["id"]
    workflow
  end
end
