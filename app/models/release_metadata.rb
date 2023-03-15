# == Schema Information
#
# Table name: release_metadata
#
#  id            :uuid             not null, primary key
#  locale        :string           not null, indexed => [train_run_id]
#  promo_text    :text
#  release_notes :text
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  train_run_id  :uuid             not null, indexed, indexed => [locale]
#
class ReleaseMetadata < ApplicationRecord
  has_paper_trail

  belongs_to :train_run, class_name: "Releases::Train::Run"
end
