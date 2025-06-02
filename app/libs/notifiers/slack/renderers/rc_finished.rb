# frozen_string_literal: true

module Notifiers
  module Slack
    class Renderers::RcFinished < Renderers::Base
      TEMPLATE_FILE = "rc_finished.json.erb"

      delegate :changes_limit, :commit_truncate_length, to: Renderers::Changelog
    end
  end
end
