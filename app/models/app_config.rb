# == Schema Information
#
# Table name: app_configs
#
#  id                                  :uuid             not null, primary key
#  bitbucket_workspace                 :string
#  bugsnag_android_config              :jsonb
#  bugsnag_ios_config                  :jsonb
#  ci_cd_workflows                     :jsonb
#  code_repository                     :json
#  firebase_android_config             :jsonb
#  firebase_crashlytics_android_config :jsonb
#  firebase_crashlytics_ios_config     :jsonb
#  firebase_ios_config                 :jsonb
#  jira_config                         :jsonb            not null
#  linear_config                       :jsonb            not null
#  notification_channel                :json
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#  app_id                              :uuid             not null, indexed
#  bitrise_project_id                  :jsonb
#  bugsnag_project_id                  :jsonb
#  codemagic_project_id                :jsonb
#
class AppConfig < ApplicationRecord
  has_paper_trail

  # self.ignored_columns += [
  #   "bitrise_project_id",
  #   "bitbucket_workspace",
  #   "bugsnag_android_config",
  #   "bugsnag_ios_config",
  #   "bugsnag_project_id",
  #   "firebase_crashlytics_android_config",
  #   "firebase_crashlytics_ios_config",
  #   "firebase_android_config",
  #   "firebase_ios_config",
  #   "notification_channel",
  #   "ci_cd_workflows",
  #   "code_repository",
  #   "jira_config",
  #   "linear_config"
  # ]

  # belongs_to :app
  # has_many :variants, class_name: "AppVariant", dependent: :destroy
end
