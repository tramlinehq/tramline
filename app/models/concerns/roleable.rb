module Roleable
  extend ActiveSupport::Concern

  included do
    enum role: {
      owner: "owner",
      developer: "play_developer",
      manager: "manager"
    }
  end
end
