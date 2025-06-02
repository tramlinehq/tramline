# frozen_string_literal: true

module Notifiers
  module Slack
    class Renderers::RcFinished < Renderers::Base
      TEMPLATE_FILE = "rc_finished.json.erb"
      delegate :changes_limit, :commit_truncate_length, to: :class

      class << self
        def changes_limit
          20
        end

        def commit_truncate_length
          70
        end
      end
    end
  end
end
