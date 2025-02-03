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
  has_many :parameters, class_name: "Config::WorkflowParameter", dependent: :destroy

  accepts_nested_attributes_for :parameters, allow_destroy: true

  enum :kind, {internal: "internal", release_candidate: "release_candidate"}
  validates :identifier, :name, presence: true
  validates :build_suffix, absence: true, if: :ios?

  delegate :ios?, to: :release_platform_config

  def as_json(options = {})
    {
      id: identifier,
      name:,
      artifact_name_pattern:,
      kind:,
      build_suffix:,
      parameters: parameters.map(&:as_json)
    }
  end

  def self.from_json(json)
    workflow = new(json.except("id", "parameters")) # Exclude 'id' to ensure we don't overwrite an existing object
    workflow.identifier = json["id"]
    if json["parameters"].present?
      workflow.parameters = json["parameters"].map { |parameter| ::Config::WorkflowParameter.new(parameter) }
    end
    workflow
  end
end
