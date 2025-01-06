# == Schema Information
#
# Table name: workflow_config_parameters
#
#  id          :bigint           not null, primary key
#  name        :string
#  value       :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  workflow_id :bigint           not null, indexed
#
class Config::WorkflowParameter < ApplicationRecord
  self.table_name = "workflow_config_parameters"
  belongs_to :workflow

  def as_json(_options = {})
    {
      name:,
      value:,
      id:
    }
  end
end
