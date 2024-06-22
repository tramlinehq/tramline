# == Schema Information
#
# Table name: workflow_runs
#
#  id                      :uuid             not null, primary key
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  pre_prod_release_id     :uuid             not null, indexed
#  release_platform_run_id :uuid             not null, indexed
#
class WorkflowRun < ApplicationRecord
  belongs_to :release_platform_run
  belongs_to :pre_prod_release
  has_one :build
end
