# == Schema Information
#
# Table name: release_changelogs
#
#  id         :uuid             not null, primary key
#  commits    :jsonb
#  from_ref   :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  release_id :uuid             not null, indexed
#
class ReleaseChangelog < ApplicationRecord
  has_paper_trail

  belongs_to :release
end
