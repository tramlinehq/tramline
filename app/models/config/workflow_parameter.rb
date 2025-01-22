# == Schema Information
#
# Table name: workflow_config_parameters
#
#  id          :bigint           not null, primary key
#  name        :string           not null, indexed => [workflow_id]
#  value       :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  workflow_id :bigint           not null, indexed, indexed => [name]
#
class Config::WorkflowParameter < ApplicationRecord
  self.table_name = "workflow_config_parameters"
  belongs_to :workflow

  validates :name, :value, presence: true
  validates :name, uniqueness: {scope: :workflow_id}

  def as_json(_options = {})
    {
      name:,
      value:,
      id:
    }
  end
end
