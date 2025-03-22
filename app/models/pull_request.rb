# == Schema Information
#
# Table name: pull_requests
#
#  id                      :uuid             not null, primary key
#  base_ref                :string           not null
#  body                    :text             indexed
#  closed_at               :datetime
#  head_ref                :string           not null, indexed => [release_id]
#  labels                  :jsonb
#  merge_commit_sha        :string
#  number                  :bigint           not null, indexed => [release_id, phase], indexed
#  opened_at               :datetime         not null
#  phase                   :string           not null, indexed => [release_id, number], indexed, indexed => [release_id]
#  search_vector           :tsvector         indexed
#  source                  :string           not null, indexed
#  state                   :string           not null, indexed
#  title                   :string           not null, indexed
#  url                     :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  commit_id               :uuid             indexed
#  release_id              :uuid             indexed => [phase, number], indexed => [head_ref], indexed => [phase]
#  release_platform_run_id :uuid
#  source_id               :string           not null, indexed
#
class PullRequest < ApplicationRecord
  has_paper_trail
  include Searchable
  include Passportable

  STAMPABLE_REASONS = %w[created merged unmergeable]

  class UnsupportedPullRequestSource < StandardError; end

  belongs_to :release
  belongs_to :commit, optional: true

  enum :phase, {
    pre_release: "pre_release",
    version_bump: "version_bump",
    mid_release: "mid_release",
    ongoing: "ongoing",
    post_release: "post_release"
  }

  enum :state, {
    open: "open",
    closed: "closed"
  }

  enum :source, {
    github: "github",
    gitlab: "gitlab",
    bitbucket: "bitbucket"
  }

  scope :automatic, -> { where(phase: [:ongoing, :post_release]) }

  validates :phase, uniqueness: {scope: :release_id, conditions: -> { open.version_bump }}

  before_save :generate_search_vector_data

  pg_search_scope :search,
    against: [:title, :body, :number],
    **search_config

  # rubocop:disable Rails/SkipsModelValidations

  def update_or_insert!(attributes)
    PullRequest
      .upsert(normalize_attributes(attributes), unique_by: [:release_id, :phase, :number])
      .rows
      .first
      .first
      .then { |id| PullRequest.find_by(id: id) }
  end

  # rubocop:enable Rails/SkipsModelValidations

  def stamp_create!
    event_stamp!(reason: :created, kind: :notice, data: stamp_data)
  end

  def stamp_merge!
    event_stamp!(reason: :merged, kind: :notice, data: stamp_data)
  end

  def stamp_unmergeable!
    event_stamp!(reason: :unmergeable, kind: :error, data: stamp_data)
  end

  private

  def normalize_attributes(attributes)
    generic_attributes = {
      release_id: release.id,
      commit_id: commit&.id,
      phase: phase,
      state: normalize_state(attributes),
      closed_at: normalize_closed_at(attributes)
    }

    attributes.merge(generic_attributes)
  end

  def normalize_state(attributes)
    case attributes[:state].to_s.downcase
    when "open", "opened", "locked"
      PullRequest.states[:open]
    when "merged", "closed"
      PullRequest.states[:closed]
    else
      PullRequest.states[:closed]
    end
  end

  def normalize_closed_at(attributes)
    if normalize_state(attributes) == PullRequest.states[:closed]
      attributes[:closed_at].presence || Time.current
    end
  end

  def generate_search_vector_data
    search_text = [title, body, number.to_s].compact.join(" ")
    self.search_vector = self.class.generate_search_vector(search_text)
  end

  def stamp_data
    slice(:url, :number, :base_ref, :head_ref)
  end
end
