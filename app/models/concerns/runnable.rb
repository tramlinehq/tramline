module Runnable
  extend ActiveSupport::Concern

  instance_methods do
    def kickoff
      create!(was_run_at: Time.current)
    end
  end
end
