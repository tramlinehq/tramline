# == Schema Information
#
# Table name: pre_prod_releases
#
#  id                      :uuid             not null, primary key
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

end
