# == Schema Information
#
# Table name: organizations
#
#  id         :uuid             not null, primary key
#  api_key    :string
#  created_by :string           not null
#  name       :string           not null
#  slug       :string           indexed
#  status     :string           not null, indexed
#  subscribed :boolean          default(FALSE)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Accounts::Organization < ApplicationRecord
  extend FriendlyId
  has_paper_trail

  has_many :memberships, dependent: :delete_all, inverse_of: :organization
  has_many :teams, -> { sequential }, dependent: :delete_all, inverse_of: :organization
  has_many :users, through: :memberships, dependent: :delete_all
  has_many :apps, -> { sequential }, dependent: :destroy, inverse_of: :organization
  has_many :releases, through: :apps
  has_many :invites, dependent: :destroy

  enum status: {active: "active", dormant: "dormant", guest: "guest"}

  encrypts :api_key, deterministic: true

  after_create :rotate_api_key

  validates :name, presence: true

  friendly_id :name, use: :slugged

  auto_strip_attributes :name, squish: true

  scope :sequential, -> { reorder("organizations.created_at ASC") }

  def demo?
    Flipper.enabled?(:demo_mode, self)
  end

  def build_notes_in_workflow?
    Flipper.enabled?(:build_notes_in_workflow, self)
  end

  def merge_only_build_notes?
    Flipper.enabled?(:merge_only_build_notes, self)
  end

  def deploy_action_enabled?
    Flipper.enabled?(:deploy_action_enabled, self)
  end

  def fixed_build_number?
    Flipper.enabled?(:fixed_build_number, self)
  end

  def custom_release_version?
    Flipper.enabled?(:custom_release_version, self)
  end

  def team_analysis_enabled?
    Flipper.enabled?(:team_analysis_enabled, self)
  end

  def owner
    users.includes(:memberships).where(memberships: {role: "owner"}).sole
  end

  def rotate_api_key
    update(api_key: SecureRandom.hex)
  end

  def default_app
    apps.first
  end

  def members
    users.includes(memberships: :organization, invitations: :organization)
  end

  def pending_invites
    invites.includes(:sender).not_accepted
  end

  def team_colors
    colors = teams.pluck(:name, :color).to_h || {}
    colors[Accounts::Team::UNKNOWN_TEAM_NAME] = Accounts::Team::UNKNOWN_TEAM_COLOR
    colors[Accounts::Team::TRAMLINE_TEAM_NAME] = Accounts::Team::TRAMLINE_TEAM_COLOR
    colors
  end

  def team_names
    return unless teams.exists?
    teams.pluck(:name) << Accounts::Team::UNKNOWN_TEAM_NAME
  end

  def teams_supported?
    teams.exists?
  end

  def team_options
    teams.pluck(:name, :id).push([Accounts::Team::UNKNOWN_TEAM_NAME, nil])
  end
end
