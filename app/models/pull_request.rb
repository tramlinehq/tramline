# == Schema Information
#
# Table name: pull_requests
#
#  id                      :uuid             not null, primary key
#  base_ref                :string           not null
#  body                    :text
#  closed_at               :datetime
#  head_ref                :string           not null, indexed => [release_id]
#  labels                  :jsonb
#  number                  :bigint           not null, indexed => [release_id, phase], indexed
#  opened_at               :datetime         not null
#  phase                   :string           not null, indexed => [release_id, number], indexed
#  source                  :string           not null, indexed
#  state                   :string           not null, indexed
#  title                   :string           not null
#  url                     :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  commit_id               :uuid             indexed
#  release_id              :uuid             indexed => [phase, number], indexed => [head_ref]
#  release_platform_run_id :uuid
#  source_id               :string           not null, indexed
#
class PullRequest < ApplicationRecord
  has_paper_trail
  include Searchable

  class UnsupportedPullRequestSource < StandardError; end

  belongs_to :release
  belongs_to :commit, optional: true

  enum :phase, {
    pre_release: "pre_release",
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

  pg_search_scope :search_by_title,
    against: :title,
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

  def close!
    self.closed_at = Time.current
    self.state = PullRequest.states[:closed]
    save!
  end

  private

  def normalize_attributes(attributes)
    generic_attributes = {
      release_id: release.id,
      commit_id: commit&.id,
      phase: phase,
      state: normalize_state(attributes[:state])
    }

    attributes.merge(generic_attributes)
  end

  def normalize_state(state)
    case state.to_s.downcase
    when "open", "opened", "locked"
      PullRequest.states[:open]
    when "merged", "closed"
      PullRequest.states[:closed]
    else
      PullRequest.states[:closed]
    end
  end
end
