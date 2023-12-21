module Notifiers
  module Slack
    class Renderers::ReviewApproved < Renderers::Base
      TEMPLATE_FILE = "review_approved.json.erb".freeze
    end
  end
end
