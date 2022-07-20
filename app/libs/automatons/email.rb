module Automatons
  class Email
    attr_reader :user, :train

    def self.dispatch!(**args)
      new(**args).dispatch!
    end

    def initialize(user:, train:)
      @user = user
      @train = train
    end

    def dispatch!
      TestMailer
        .with(user_id: user.id, was_run_at: Time.zone.now, train_name: train.name)
        .verify
        .deliver_now
    end
  end
end
