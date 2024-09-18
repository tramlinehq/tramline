# == Schema Information
#
# Table name: submission_external_configs
#
#  id                   :bigint           not null, primary key
#  identifier           :string
#  internal             :boolean          default(FALSE)
#  name                 :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  submission_config_id :bigint           indexed
#
class Config::SubmissionExternal < ApplicationRecord
  self.table_name = "submission_external_configs"

  belongs_to :submission_config, class_name: "Config::Submission"

  def as_json(options = {})
    {
      id: identifier,
      name: name,
      is_internal: internal
    }
  end

  def self.from_json(json)
    sub = new(json.except("id", "submission_config_id", "is_internal", "is_production"))
    sub.identifier = json["id"]
    sub.internal = json["is_internal"]
    sub
  end
end
