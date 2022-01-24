class Integration < ApplicationRecord
  belongs_to :app

  unless const_defined?(:LIST)
    LIST = {
      "version_control" => ["github"],
      "ci_cd" => ["github_actions"],
      "app_store" => ["google_play_store"]
    }.freeze
  end

  enum category: LIST.keys.zip(LIST.keys).to_h
  enum provider: LIST.values.flatten.zip(LIST.values.flatten).to_h

  validate -> { provider.in?(LIST[category]) }

  encrypts :access_token, deterministic: true, ignore_case: true
end
