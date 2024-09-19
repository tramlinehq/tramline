# == Schema Information
#
# Table name: release_step_configs
#
#  id                         :bigint           not null, primary key
#  auto_promote               :boolean          default(FALSE)
#  kind                       :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  release_platform_config_id :bigint           indexed
#
class Config::ReleaseStep < ApplicationRecord
  self.table_name = "release_step_configs"

  belongs_to :release_platform_config, class_name: "Config::ReleasePlatform"
  has_many :submissions, class_name: "Config::Submission", inverse_of: :release_step_config, dependent: :destroy

  accepts_nested_attributes_for :submissions

  enum :kind, {internal: "internal", beta: "beta", production: "production"}

  def as_json(options = {})
    {
      auto_promote: auto_promote,
      submissions: submissions.map(&:as_json)
    }
  end

  def last_submission
    submissions.order(number: :desc).first
  end

  def first_submission
    submissions.order(number: :asc).first
  end

  def fetch_submission_by_number(number)
    # rubocop:disable Performance/Detect
    submissions.filter { |s| s.number == number }.first
    # rubocop:enable Performance/Detect
  end

  def fetch_by_number(num)
    found = value.find { |d| d[:number] == num }
    found ? Submission.new(found, value) : nil
  end

  def self.from_json(json)
    release_step = new(json.except("submissions", "id", "release_platform_config_id"))
    release_step.submissions = json["submissions"].map { |submission_json| Config::Submission.from_json(submission_json) }
    release_step
  end
end
