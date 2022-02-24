module Roleable
  extend ActiveSupport::Concern

  included do
    enum role: {
      owner: "owner",
      developer: "developer",
      manager: "manager"
    }
  end
end
