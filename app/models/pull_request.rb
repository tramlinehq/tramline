# == Schema Information
#
# Table name: pull_requests
#
#  id                      :uuid             not null, primary key
#  base_ref                :string           not null
#  body                    :text             indexed
#  closed_at               :datetime
#  head_ref                :string           not null, indexed => [release_id]
#  kind                    :string           indexed => [release_id]
#  labels                  :jsonb
#  merge_commit_sha        :string           indexed
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
#  release_id              :uuid             indexed => [phase, number], indexed => [head_ref], indexed => [kind], indexed => [phase]
#  release_platform_run_id :uuid
#  source_id               :string           not null, indexed
#
class PullRequest < ApplicationRecord
  has_paper_trail
  include Searchable
  include Displayable
  include Passportable

  STAMPABLE_REASONS = %w[created merged unmergeable]

  class UnsupportedPullRequestSource < StandardError; end

  belongs_to :release
  belongs_to :commit, optional: true

  enum :phase, {
    pre_release: "pre_release",
    mid_release: "mid_release",
    post_release: "post_release"
  }

  enum :kind, {
    stability: "stability",
    forward_merge: "forward_merge",
    back_merge: "back_merge",
    version_bump: "version_bump"
  }, suffix: :type

  enum :state, {
    open: "open",
    closed: "closed"
  }

  enum :source, {
    github: "github",
    gitlab: "gitlab",
    bitbucket: "bitbucket"
  }

  validates :kind, uniqueness: {scope: :release_id, conditions: -> { version_bump_type.open }}
  validates :phase, uniqueness: {scope: :release_id, conditions: -> { pre_release.version_bump_type }}

  before_save :generate_search_vector_data

  pg_search_scope :search,
    against: [:title, :body, :number],
    **search_config

  delegate :platform, to: :release

  class << self
    # rubocop:disable Rails/SkipsModelValidations

    def update_or_insert!(attributes)
      attributes = attributes.with_indifferent_access
      raise ArgumentError, "attributes must be a Hash" unless attributes.is_a?(Hash)
      raise ArgumentError, "attributes must include a release_id" if attributes[:release_id].blank?
      raise ArgumentError, "attributes must include a phase" if attributes[:phase].blank?
      raise ArgumentError, "attributes must include a number" if attributes[:number].blank?

      PullRequest
        .upsert(normalize_attributes(attributes), unique_by: [:release_id, :phase, :number])
        .rows
        .first
        .first
        .then { |id| PullRequest.find_by(id: id) }
    end

    # rubocop:enable Rails/SkipsModelValidations

    def normalize_attributes(attributes)
      generic_attributes = {
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
  end

  delegate :normalize_attributes, to: self

  def safe_update!(attributes)
    update!(normalize_attributes(attributes))
  end

  def stamp_create!
    event_stamp_now!(reason: :created, kind: :notice, data: stamp_data)
  end

  def stamp_merge!
    event_stamp_now!(reason: :merged, kind: :notice, data: stamp_data)
  end

  def stamp_unmergeable!
    event_stamp_now!(reason: :unmergeable, kind: :error, data: stamp_data)
  end

  def pre_release_version_bump?
    pre_release? && version_bump_type?
  end

  private

  def generate_search_vector_data
    search_text = [title, body, number.to_s].compact.join(" ")
    self.search_vector = self.class.generate_search_vector(search_text)
  end

  def stamp_data
    slice(:url, :number, :base_ref, :head_ref).merge(phase: display_attr(:phase), kind: display_attr(:kind))
  end
end
