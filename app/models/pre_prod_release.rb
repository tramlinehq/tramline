# == Schema Information
#
# Table name: pre_prod_releases
#
#  id                      :bigint           not null, primary key
#  type                    :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  build_id                :uuid             indexed
#  release_platform_run_id :uuid             not null, indexed
#
class PreProdRelease < ApplicationRecord
  include AASM
  include Passportable
  include Loggable
  include Displayable

  belongs_to :release_platform_run
  belongs_to :build, optional: true
  has_one :workflow_run, dependent: :destroy
  has_many :store_submissions, dependent: :destroy

  def attach_build!(build)
    update!(build: build)
  end

  def trigger_workflow!
    create_workflow_run!(workflow: workflow)
  end

  def trigger_submission!
    # TODO: Implement this
  end

  def build_upload_failed!
    # TODO: Implement this
  end
end
