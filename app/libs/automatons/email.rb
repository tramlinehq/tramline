module Automatons
  class Email
    attr_reader :user

    def self.dispatch!(**args)
      new(**args).dispatch!
    end

    def initialize(user:)
      @user = user
    end

    def dispatch!
      TestMailer.with(user_id: user.id, was_run_at: Time.now).verify.deliver_now
    end
  end
end
